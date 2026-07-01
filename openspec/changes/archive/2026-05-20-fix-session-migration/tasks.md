## 1. Migration State Tracking

- [x] 1.1 Add `migratingDownloadIDs: Set<UUID>` property to `DownloadEngine` actor to track downloads being intentionally cancelled for session migration
- [x] 1.2 Add `pendingMigrationCount: Int` property and `backgroundTaskID: UIBackgroundTaskIdentifier?` property to `DownloadEngine` for tracking migration completion

## 2. Background Task Protection

- [x] 2.1 In `handleWillResignActive()`, call `UIApplication.shared.beginBackgroundTask(expirationHandler:)` before calling `migrateToBackground()`. Store the task ID. In expiration handler, call `endBackgroundTask` and log warning.
- [x] 2.2 In `restartOnBackground()`, decrement `pendingMigrationCount`. When count reaches 0, call `UIApplication.shared.endBackgroundTask` with stored ID and reset ID to `.invalid`.

## 3. Cancellation Suppression

- [x] 3.1 In `migrateToBackground()`, insert each foreground download ID into `migratingDownloadIDs` before calling `cancel(byProducingResumeData:)`
- [x] 3.2 In `restartOnBackground()`, remove the download ID from `migratingDownloadIDs` after the replacement task is created
- [x] 3.3 In `handleError()`, add early return when error is `NSURLErrorCancelled` and download ID is in `migratingDownloadIDs` — do not post failure notification, do not increment retry count

## 4. Chunked Download Migration

- [x] 4.1 Add `cancelAll()` method to `ChunkCoordinator` that cancels all in-flight chunk data tasks on the ephemeral session
- [x] 4.2 Add `activeChunkCoordinators: [UUID: ChunkCoordinator]` tracking to `DownloadQueueManager` so the engine can signal chunk cancellation on backgrounding
- [x] 4.3 In `DownloadQueueManager`, observe `willResignActiveNotification` — cancel active `ChunkCoordinator` tasks, clean up partial chunk files, and start a single-stream download on the background session via `DownloadEngine.startDownload()`

## 5. Verification

- [x] 5.1 Test single-stream download survives screen lock without "Cancelled" error
- [x] 5.2 Test single-stream download survives app backgrounding (home button) without "Cancelled" error
- [x] 5.3 Test chunked download falls back to single-stream on backgrounding and completes
