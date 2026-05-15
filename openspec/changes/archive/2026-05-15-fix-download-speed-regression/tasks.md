## 1. Remove Dead Code

- [x] 1.1 Delete the `startChunkDownload(id:chunkIndex:url:rangeStart:rangeEnd:)` method from `DownloadEngine.swift` — it is never called by `ChunkCoordinator` and has a correctness bug (overwrites `activeTasks` entries per-download instead of per-chunk)

## 2. Add Foreground Session to DownloadEngine

- [x] 2.1 Add a second `URLSession` property `foregroundSession` to `DownloadEngine` using `URLSessionConfiguration.default` with `httpMaximumConnectionsPerHost = 6`, sharing the same delegate (`self`) and delegate queue
- [x] 2.2 Add an `isAppActive: Bool` property to the actor, initialized to `true`
- [x] 2.3 Add a `SessionKind` enum (`.foreground`, `.background`) field to the existing `ActiveTask` struct to track which session each task belongs to

## 3. App Lifecycle Observation

- [x] 3.1 Subscribe to `UIApplication.willResignActiveNotification` in `DownloadEngine.init()` — on notification, set `isAppActive = false` and call a new `migrateToBackground()` method
- [x] 3.2 Subscribe to `UIApplication.didBecomeActiveNotification` in `DownloadEngine.init()` — on notification, set `isAppActive = true` (no task migration on return to foreground)
- [x] 3.3 Implement `migrateToBackground()`: iterate all `activeTasks` where `sessionKind == .foreground`, cancel each with `cancel(byProducingResumeData:)`, and restart on the background session using resume data (or from scratch if resume data is nil)

## 4. Route Downloads Through Correct Session

- [x] 4.1 Modify `startDownload(id:url:resumeData:)` to check `isAppActive` — if `true`, create the download task on `foregroundSession`; if `false`, create it on the existing background `session`. Set `sessionKind` on the `ActiveTask` accordingly
- [x] 4.2 Update `retryDownload(entry:)` to create the new task on the same session kind that the failed task was using (read `sessionKind` from the entry)

## 5. Verify and Test

- [x] 5.1 Build the project and verify no compilation errors
- [x] 5.2 Verify that `ChunkCoordinator` and `ChunkManager` are completely unaffected (no changes to those files)
- [x] 5.3 Verify that `DownloadQueueManager` requires no changes (its API calls to `DownloadEngine.startDownload()` are unchanged)
