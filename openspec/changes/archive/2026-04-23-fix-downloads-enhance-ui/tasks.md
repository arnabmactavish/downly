## 1. Background Download Support (Phase 1 — Bug Fix)

- [x] 1.1 Switch `DownloadEngine.init()` from `URLSessionConfiguration.default` to `URLSessionConfiguration.background(withIdentifier: "com.axoman.downly.bgdownload")`. Set `isDiscretionary = false` and `sessionSendsLaunchEvents = true`.
- [x] 1.2 Add or update `AppDelegate` (or `@UIApplicationDelegateAdaptor`) to implement `application(_:handleEventsForBackgroundURLSession:completionHandler:)` and store the handler in `DownloadEngine.shared`.
- [x] 1.3 Ensure `DownloadEngine.shared` is initialized early on app launch so background session delegate callbacks are reconnected.
- [x] 1.4 Add `UIBackgroundModes` → `fetch` to `Info.plist` if not already present (required for background URLSession).
- [x] 1.5 Verify that `didFinishDownloadingTo:` synchronous file copy still works correctly when called from a background launch context.

## 2. Chunk Temp File Durability (Phase 1 — Bug Fix)

- [x] 2.1 Update `ChunkCoordinator.downloadChunk()` to write chunk temp files to the App Group container's `tmp/` subdirectory (`group.com.axoman.downly/tmp/`) instead of `FileManager.default.temporaryDirectory`.
- [x] 2.2 Update `DownloadQueueManager.executeDownload()` to pass the App Group `tmp/` URL as `tempDir` to `ChunkCoordinator.downloadAll()`.
- [x] 2.3 Update `FileAssemblyEngine.cleanupOrphanedTempFiles()` to also scan the App Group container's `tmp/` directory.
- [x] 2.4 Add a zero-byte chunk guard in `FileAssemblyEngine.merge()`: if a chunk temp file exists but has 0 bytes, throw `FileAssemblyError.chunkFileMissing` with a descriptive message.

## 3. Enriched Error Messages (Phase 1 — Bug Fix)

- [x] 3.1 Update `FileAssemblyError.chunkFileMissing` error description to include chunk index, expected path, and total chunk count.
- [x] 3.2 Verify that `FileAssemblyError.sizeMismatch` already includes both expected and actual byte counts in its `errorDescription` (it does — confirm no changes needed).
- [x] 3.3 Ensure all error messages from `DownloadQueueManager.markError()` flow through to `DownloadItem.errorMessage` without truncation.

## 4. Cancel → Live Activity Cleanup (Phase 1 — Bug Fix)

- [x] 4.1 In `DownloadQueueManager.cancelDownload(id:)`, add a `Task` that calls `await LiveActivityManager.shared.endActivity(id: id, policy: .immediate)` to dismiss the Live Activity.
- [x] 4.2 Verify that bulk cancel from edit mode (iterating `selectedIDs`) also triggers Live Activity cleanup for each ID.

## 5. Error Log Export (Phase 1 — Bug Fix)

- [x] 5.1 Create `ErrorDetailSheet.swift` in `UI/Components/` — a SwiftUI `.sheet` view that displays the full error message, file name, URL, and error timestamp.
- [x] 5.2 Add a "Copy" button in `ErrorDetailSheet` that copies the formatted error report to `UIPasteboard.general.string` with haptic feedback confirmation.
- [x] 5.3 Add a "Share" button in `ErrorDetailSheet` using `ShareLink` that shares the error report as text.
- [x] 5.4 In `DownloadItemCard`, make the error state card tappable to present `ErrorDetailSheet`. Add `@State private var showErrorDetail = false` and a `.sheet(isPresented:)` modifier.

## 6. ETA Display (Phase 2 — UI Enhancement)

- [x] 6.1 Add `estimatedSecondsRemaining: Int?` property to `DownloadItem` SwiftData model.
- [x] 6.2 Update `PersistenceThrottle` save closure signature and `DownloadProgressCoordinator.handleProgress()` to persist `estimatedSecondsRemaining` from `DownloadProgress.eta`.
- [x] 6.3 Clear `estimatedSecondsRemaining` to `nil` in `markCompleted()` and `markError()`.
- [x] 6.4 Create a `formatETA(_ seconds: Int?) -> String?` helper function that returns human-readable strings ("~30 sec remaining", "~2 min remaining", "~1 hr 15 min remaining").
- [x] 6.5 Update `DownloadItemCard` to display the formatted ETA in the progress percentage row, replacing the static "remaining" bytes label.

## 7. Initializing State (Phase 2 — UI Enhancement)

- [x] 7.1 Create a `ShimmerProgressBar` SwiftUI view — an indeterminate progress indicator with a horizontally-sweeping gradient animation.
- [x] 7.2 Add an `isInitializing` computed property to `DownloadItemCard` (or inline check): `item.status == .running && item.downloadedSize == 0 && item.totalSize == 0`.
- [x] 7.3 When `isInitializing` is true, show `ShimmerProgressBar` and "Initializing…" text instead of the normal `DownloadProgressBar` and byte stats.
- [x] 7.4 When `item.status == .pending`, show "Waiting…" text with a subtle pulse animation on the status dot.
- [x] 7.5 Ensure the transition from initializing/waiting to normal progress is animated with `.downlySpring`.

## 8. Settings "Done" Button Removal (Phase 2 — UI Enhancement)

- [x] 8.1 Remove the `.toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }` block from `SettingsView`.
- [x] 8.2 Remove the `@Environment(\.dismiss) private var dismiss` property from `SettingsView` since it is no longer needed.

## 9. Edit Mode Redesign (Phase 2 — UI Enhancement)

- [x] 9.1 In `DownloadListView`, change the edit mode toolbar to show only an "✕" close icon (`xmark.circle.fill`) instead of the current "Delete" + "Done" HStack.
- [x] 9.2 Move the selection checkbox from the `.overlay(alignment: .topLeading)` to a leading `HStack` position before the card. Add `.padding(.leading, isEditMode ? 44 : 0)` to the card with spring animation.
- [x] 9.3 Create a floating delete FAB — a 56pt circle with red/error tint and white trash icon — positioned at `.bottomTrailing` via an overlay on the `ScrollView`. Show it only when `isEditMode && !selectedIDs.isEmpty`.
- [x] 9.4 Wire the delete FAB to iterate `selectedIDs`, call `cancelDownload(id:)` for each, clear selections, but keep edit mode active.
- [x] 9.5 Add bottom padding to the `ScrollView` content when edit mode is active to prevent the FAB from overlapping the last card.
- [x] 9.6 Ensure that the delete FAB also triggers Live Activity cleanup (covered by task 4.1/4.2 via `cancelDownload`).
