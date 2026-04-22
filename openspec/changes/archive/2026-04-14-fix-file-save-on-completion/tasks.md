## 1. Fix `DownloadEngine` — Synchronous Temp File Copy

- [x] 1.1 In `DownloadEngine+URLSessionDownloadDelegate`, refactor
  `urlSession(_:downloadTask:didFinishDownloadingTo:)`:
  - Extract App Group staging directory resolution and `copyItem` call to run
    **synchronously** on the delegate queue before the method returns.
  - On copy failure post a `.downloadTaskDidFail` notification via a detached
    `Task` and return early.
  - On success, dispatch `Task { await self.handleCompletion(...) }` passing
    the `stableURL` (not the original `location`).

- [x] 1.2 Simplify `handleCompletion(downloadID:chunkIndex:stableLocation:)`:
  - Remove the `FileManager.copyItem` / `createDirectory` block — the file is
    already at `stableLocation`.
  - Rename the parameter from `tempLocation: URL` to `stableLocation: URL` for
    clarity.
  - Keep the notification post (`downloadTaskDidFinish`) and actor state cleanup
    (remove from `activeTasks`, finish `progressContinuations`) unchanged.
  - Add a `postFailure(downloadID:message:)` private helper that wraps the
    `.downloadTaskDidFail` notification post to DRY up error paths.

## 2. Verification

- [x] 2.1 Build the app (Debug, Simulator). Must succeed with zero errors and
  zero warnings introduced by this change.
- [ ] 2.2 Trigger a download. Confirm `[Downly]` progress logs appear in the
  Xcode console throughout the download.
- [ ] 2.3 Let the download reach 100%. Confirm:
  - No `FILE-ERROR [staging]` log line appears.
  - A `[Downly] ✅ DONE` log line appears with a valid path.
  - The download card shows status `completed`.
- [ ] 2.4 Verify the file exists on disk at the logged path using Xcode's
  Device File Browser (or `ls` via terminal for a simulator).
- [ ] 2.5 On device: open the Files app → On My iPhone → Downly and confirm
  the downloaded file is visible.
