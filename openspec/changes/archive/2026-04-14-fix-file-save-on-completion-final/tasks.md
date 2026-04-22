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

## 2. Fix `DownloadQueueManager` — Notification Race & Filename Resolution

- [x] 2.1 Fix notification race in `waitForSingleStreamCompletion`:
  - The listener is registered **after** `engine.startDownload()`, so for fast
    downloads the `downloadTaskDidFinish` notification fires before the `for await`
    loop is entered and is silently dropped.
  - Refactor `executeDownload` to register a `NotificationCenter` observer
    **before** calling `engine.startDownload()`, using `Task` + `AsyncStream`
    bridge or `withCheckedContinuation` so the notification is never missed.

- [x] 2.2 Apply `Content-Disposition` filename from server HEAD response:
  - After `chunkManager.analyzeServer()` returns, if `capability.suggestedFileName`
    is non-nil and non-empty, update `item.fileName` (and the local `fileName`
    variable used for `documentsURL`) to use it.
  - This ensures the final file is named after the server's intended name, not the
    URL path component fallback.

## 3. Fix `AddDownloadSheet` — Filename Field Should Be Placeholder, Not Pre-filled

- [x] 3.1 Change `deriveFileName` so it sets the TextField **placeholder** string
  (a new `@State private var fileNamePlaceholder`) instead of pre-filling `fileName`.
  - The `fileName` field stays empty until the user types.
  - The placeholder shows the URL-derived name hint greyed out.
  - On submit, if `fileName` is empty, fall back to `fileNamePlaceholder` then to
    `URL.lastPathComponent` then to `"download"`.
  - This way the server `Content-Disposition` name (resolved inside
    `executeDownload`) always wins over the URL-derived hint.

## 4. Verification

- [x] 4.1 Build the app (Debug, Simulator). Must succeed with zero errors and
  zero warnings introduced by this change.
- [ ] 4.2 Trigger a download (small file, fast). Confirm no hanging — download
  completes and status transitions to `completed`.
- [ ] 4.3 Confirm a `MOVE` or file-present log / the file exists in
  `Documents/` inside the App Group container.
- [ ] 4.4 Trigger a download with a URL that returns `Content-Disposition:
  attachment; filename="myfile.zip"`. Confirm the saved file is named `myfile.zip`
  not the URL path fragment.
- [ ] 4.5 On device: Files app → On My iPhone → Downly — downloaded file is visible.
