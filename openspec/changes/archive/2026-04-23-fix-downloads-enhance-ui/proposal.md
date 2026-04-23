## Why

Downly's download engine has several reliability issues that degrade the core user experience: downloads silently halt when the device screen locks (no background execution entitlement, foreground-only `URLSessionConfiguration.default`), large chunked files fail at 100% during the merge phase with no way for users to inspect or export the error, and cancelling a download leaves an orphaned Live Activity on the Lock Screen. Additionally, the download list UI lacks polish — there's no initializing state, no ETA display, the Settings screen has a redundant "Done" button, and the edit-mode interaction pattern (checkbox overlay, inline delete) is non-standard and cramped.

## What Changes

### Phase 1 — Bug Fixes

- **Background download support**: Replace `URLSessionConfiguration.default` with a proper `URLSessionConfiguration.background` session so downloads continue when the app is backgrounded or the screen locks. Wire the system's `application(_:handleEventsForBackgroundURLSession:completionHandler:)` callback into the engine.
- **Chunk merge error resilience**: Audit the `FileAssemblyEngine.merge()` path for edge cases (temp file eviction by iOS, partial writes). Surface detailed, actionable error messages via `FileAssemblyError`.
- **Error log export**: Add a mechanism for users to long-press or tap an errored download card to view the full error string and share/copy it.
- **Cancel → Live Activity cleanup**: Ensure `cancelDownload(id:)` in `DownloadQueueManager` also ends the associated Live Activity via `LiveActivityManager.endActivity(id:)`.

### Phase 2 — UI/UX Enhancements

- **Initializing state indicator**: When a download is freshly enqueued and has `downloadedSize == 0` and `totalSize == 0`, show an "Initializing…" label with a shimmer/indeterminate progress animation instead of "Zero KB".
- **Estimated time remaining**: Display a human-readable ETA (e.g., "~2 min remaining") on the download card while a download is running, using the `estimatedSecondsRemaining` already computed in `DownloadProgress`.
- **Remove Settings "Done" button**: Since Settings is now a tab (not a modal sheet), remove the `ToolbarItem` with the "Done" dismiss button.
- **Edit mode redesign**:
  - Selection checkbox appears to the **leading edge** of the card; the card shifts right with animation.
  - A floating **trash/delete button** appears pinned to the **bottom-right corner** of the screen.
  - The "Edit" toolbar button transforms into an **"✕" (close) icon** during edit mode.

## Capabilities

### New Capabilities
- `error-log-export`: Ability for users to view, copy, and share full error details from a failed download card.
- `download-eta-display`: Show estimated time remaining on the download card during active downloads.
- `initializing-state`: Visual indicator (shimmer animation + "Initializing…" label) for freshly enqueued downloads before bytes start flowing.
- `edit-mode-redesign`: Redesigned edit mode with leading checkboxes, floating delete FAB, and close icon toggle.

### Modified Capabilities
- `download-engine`: Switch from foreground `URLSessionConfiguration.default` to `URLSessionConfiguration.background` so downloads survive app backgrounding and screen lock.
- `file-assembly`: Harden chunk merge against temp file eviction and surface richer error diagnostics.
- `live-activity`: End the Live Activity when a download is cancelled (not just on completion/error).
- `download-ui`: Remove the redundant "Done" button from the Settings tab toolbar.

## Impact

- **DownloadEngine.swift**: Session configuration change (`.default` → `.background`), delegate wiring for background events.
- **DownloadQueueManager.swift**: Cancel path must call `LiveActivityManager.endActivity`; initializing state logic.
- **LiveActivityManager.swift**: New `endOnCancel(id:)` convenience or reuse of `endActivity(id:, policy: .immediate)`.
- **FileAssemblyEngine.swift**: Additional validation, richer error messages, temp file existence guards.
- **DownloadItemCard.swift**: Initializing state shimmer, ETA label, error detail tap/long-press, edit-mode layout shift.
- **DownloadListView.swift**: Edit mode toolbar/FAB redesign, leading checkbox layout.
- **SettingsView.swift**: Remove `ToolbarItem(placement: .topBarTrailing)` with "Done" button.
- **DownloadProgressCoordinator.swift**: Persist `estimatedSecondsRemaining` to SwiftData for card display.
- **DownloadItem.swift**: New `estimatedSecondsRemaining: Int?` persisted property.
- **Info.plist / Entitlements**: May need `UIBackgroundModes` → `processing` or background fetch if using background URLSession.
