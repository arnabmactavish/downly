## Why

Downloads stop with a "Cancelled" error when the app moves to background or the screen locks. The dual-session migration (`migrateToBackground`) has multiple race conditions: the `cancel(byProducingResumeData:)` callback runs asynchronously via `Task`, but iOS suspends the process before the replacement background task can be created. Additionally, `ChunkCoordinator` uses an ephemeral URLSession that iOS kills on suspension, and the error handler treats migration-induced cancellations as real failures.

## What Changes

- **Fix migration race condition**: Use `UIApplication.beginBackgroundTask` to buy execution time during `willResignActive` so `restartOnBackground` can finish before suspension.
- **Suppress migration cancellation errors**: Track "migrating" download IDs so `handleError` ignores `NSURLErrorCancelled` (-999) for tasks being intentionally cancelled for migration.
- **Handle chunked downloads on backgrounding**: When app backgrounds during a chunked download (running on `ChunkCoordinator`'s ephemeral session), cancel chunks gracefully, persist partial chunk progress, and restart as a single-stream download on the background `URLSession`.
- **Fix `handleDidBecomeActive`**: When returning to foreground, restart stalled/cancelled tasks that failed to migrate properly.

## Capabilities

### New Capabilities

_None — this is a bug-fix change._

### Modified Capabilities

- `dual-session-engine`: Migration must use `beginBackgroundTask` for execution time, suppress migration-induced cancellations, and handle chunked downloads during session switching.
- `download-engine`: Error handler must distinguish migration-cancellations from real failures; chunked-to-single-stream fallback on backgrounding.

## Impact

- **`DownloadEngine.swift`**: `migrateToBackground()`, `handleError()`, `handleWillResignActive()`, `handleDidBecomeActive()` — all need changes.
- **`ChunkCoordinator.swift`**: Needs cancellation support so in-flight chunks can be stopped cleanly during migration.
- **`DownloadQueueManager.swift`**: May need to handle re-enqueue of chunked downloads that were interrupted by session migration.
- **No API changes** — all fixes are internal to the engine layer.
