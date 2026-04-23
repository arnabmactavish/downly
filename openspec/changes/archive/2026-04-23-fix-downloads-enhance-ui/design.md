## Context

Downly is a native iOS download manager built with SwiftUI, SwiftData, and Swift Concurrency. The current architecture uses:

- **DownloadEngine** (actor): Wraps a `URLSessionConfiguration.default` session with download-delegate callbacks. Progress is delivered via `AsyncStream`, and completion/failure are broadcast through `NotificationCenter`.
- **ChunkCoordinator** (actor): Orchestrates parallel chunk downloads using an ephemeral `URLSession.data(for:)` session, writing each chunk to a temp file.
- **FileAssemblyEngine** (struct): Merges chunk temp files into the final output using `FileHandle` streaming. Validates file size post-merge.
- **DownloadQueueManager** (@MainActor ObservableObject): Enqueues operations, wires progress coordinators, handles completion/error state transitions, and manages Live Activity lifecycle.
- **LiveActivityManager** (actor): Manages ActivityKit Live Activities with throttled updates (2s window).

### Key constraints
- The app targets iOS 16.2+ for Live Activities, iOS 17+ for SwiftData.
- Files are saved to the app sandbox `Documents/` (exposed via `UIFileSharingEnabled`).
- Chunk temp files are written to `FileManager.default.temporaryDirectory`, which iOS can purge at any time when the app is backgrounded.

## Goals / Non-Goals

**Goals:**
- Downloads MUST continue when the device screen locks or the app is backgrounded.
- Large chunked files MUST NOT fail silently at 100% due to temp file eviction or merge errors.
- Users MUST be able to inspect and export error details from failed downloads.
- Cancelling a download MUST dismiss any associated Live Activity.
- The download card MUST show a clear "Initializing…" state with animation before bytes flow.
- The download card MUST display estimated time remaining during active downloads.
- Edit mode MUST use a leading checkbox + floating delete FAB pattern.
- The Settings tab MUST NOT show a "Done" button.

**Non-Goals:**
- Background refresh / silent push-triggered downloads (requires server infra).
- Download scheduling or Wi-Fi-only mode.
- Notification-based download complete alerts (separate feature).
- Redesigning the Add Download sheet.
- iPad split-view or macOS Catalyst support.

## Decisions

### D1: Background URLSession for single-stream downloads

**Decision**: Replace `URLSessionConfiguration.default` with `URLSessionConfiguration.background(withIdentifier:)` for the main download session in `DownloadEngine`.

**Rationale**: The current `.default` session is tied to the app's process lifecycle. When iOS suspends the app (screen lock, home gesture), all active `URLSessionDownloadTask`s are paused. A background session hands off the actual download to the system daemon (`nsurlsessiond`), which continues independently.

**Alternatives considered**:
- *BGProcessingTask*: Doesn't support long-running network transfers; designed for maintenance work.
- *Audio background mode*: Hack that violates App Store review guidelines.

**Implementation notes**:
- The background session identifier MUST be stable across app launches (e.g., `"com.axoman.downly.bgdownload"`).
- `urlSessionDidFinishEvents(forBackgroundURLSession:)` must call the system-provided completion handler stored in AppDelegate/SceneDelegate.
- The `didFinishDownloadingTo:` delegate fires in a background launch — the synchronous file copy to staging is already correct.
- `isDiscretionary` should be `false` so downloads begin immediately.

### D2: Chunk downloads remain foreground (ephemeral)

**Decision**: Keep `ChunkCoordinator`'s ephemeral `URLSession.data(for:)` approach for chunked parallel downloads. Do NOT convert chunk tasks to background session tasks.

**Rationale**: Background `URLSession` only supports `downloadTask` (not `data(for:)`), and managing 20+ concurrent background tasks for one file creates excessive system overhead. Instead, the single-stream fallback via background session will keep the download alive. If the app is backgrounded mid-chunk, the coordinator will be suspended and resume when the app returns to foreground. The already-written `.partN` files persist in the temp directory.

**Risk**: iOS may purge `tmp/` files during extended backgrounding. **Mitigation**: See D3.

### D3: Chunk temp files written to App Group container, not `tmp/`

**Decision**: Move chunk temp file storage from `FileManager.default.temporaryDirectory` to the App Group container's `tmp/` subdirectory (`group.com.axoman.downly/tmp/`).

**Rationale**: The system `tmp/` directory is aggressively purged when the app is backgrounded. The App Group container is more durable. This directly addresses the "big files fail at 100%" bug — chunk files were being evicted between the last chunk completing and the merge starting.

**Alternatives considered**:
- *Sandbox `Library/Caches/`*: Also purgeable by the system under storage pressure.
- *Sandbox `Documents/`*: Not appropriate for transient data.

### D4: Error detail sheet with share/copy

**Decision**: Add a tap gesture on errored download cards that presents a `.sheet` with the full error message, plus Copy and Share buttons.

**Rationale**: The current UI truncates the error to one line (`lineLimit(1)`). Users need the full string for debugging and bug reports. A sheet is the most natural iOS pattern for detail views.

**Alternatives considered**:
- *Alert*: Too small for long error strings.
- *Contextual menu*: Not discoverable enough.
- *Console log export*: Too complex for Phase 1; could be added later.

### D5: Edit mode with leading checkboxes and floating FAB

**Decision**: Redesign edit mode with:
1. Selection checkboxes appear at the **leading edge** of each card, with the card animating rightward via `.padding(.leading, isEditMode ? 40 : 0)`.
2. A floating circular delete button pinned to `.bottomTrailing` using an overlay on the `ScrollView`.
3. The "Edit" toolbar button becomes an "✕" icon (`xmark.circle.fill`) during edit mode.

**Rationale**: The current overlay-based checkbox obscures the card's status dot. Leading checkboxes follow iOS Mail and Files app conventions. A floating delete FAB is more discoverable than an inline toolbar button and works well with one-handed use.

### D6: ETA display using existing speed data

**Decision**: Persist `estimatedSecondsRemaining` (already computed in `DownloadProgress.eta`) to a new `Int?` property on `DownloadItem` via `PersistenceThrottle`, and display it formatted on the card.

**Rationale**: The engine already computes ETA from `(remainingBytes / speed)`. It just isn't persisted to SwiftData or shown in the UI. This is a low-effort, high-impact improvement.

### D7: Initializing state shimmer

**Decision**: When `item.status == .running` and `item.downloadedSize == 0` and `item.totalSize == 0`, show an "Initializing…" label and a shimmer/indeterminate progress bar animation instead of the normal progress bar and "Zero KB" stats.

**Rationale**: There's a real delay between enqueue and the first progress callback (HEAD request + connection setup). The current "Zero KB" display looks broken.

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Background URLSession requires the app to handle relaunches — `didFinishDownloadingTo` may fire in a cold launch context | The existing synchronous file copy in the delegate is already launch-safe. Ensure `DownloadEngine.shared` is initialized early in `application(_:didFinishLaunchingWithOptions:)`. |
| Chunk temp files in App Group container consume more durable storage | `FileAssemblyEngine.cleanupOrphanedTempFiles` already runs at launch; extend it to scan the App Group `tmp/` as well. |
| Background session limits concurrent tasks (system-managed priority) | Only single-stream downloads use the background session; chunked downloads remain foreground. The queue already limits to 3 concurrent operations. |
| `estimatedSecondsRemaining` can fluctuate wildly on unstable connections | Apply a simple exponential moving average to smooth the ETA before display. |
| Edit mode FAB may overlap content on small screens | Ensure the `ScrollView` has bottom padding equal to the FAB's height + margin when edit mode is active. |
