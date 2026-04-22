## Why

Downloads reach 100% progress but the file is never saved to disk. The error
message reveals the root cause:

```
FILE-ERROR [staging] — The file "CFNetworkDownload_rNRHDf.tmp" couldn't be
opened because there is no such file or directory.
```

`URLSession` delivers the completed download file via the delegate callback
`urlSession(_:downloadTask:didFinishDownloadingTo:)`. The `location` URL passed
to that method points to a **temporary** scratch file that iOS owns. Apple's
contract is explicit: **the file is valid only for the duration of that delegate
call**; once the delegate method returns, iOS deletes it. 

The current `DownloadEngine` wraps the handler body in a `Task { }` block:

```swift
nonisolated func urlSession(_:downloadTask:didFinishDownloadingTo location: URL) {
    Task {
        await self.handleCompletion(downloadID: downloadID, chunkIndex: chunkIndex, tempLocation: location)
    }
}
```

The `Task { }` executes **asynchronously** — by the time `handleCompletion`
runs (even a few milliseconds later), iOS has already deleted the
`CFNetworkDownload_*.tmp` file. The `copyItem(at: tempLocation, to: stableLocation)`
call then fails with "no such file or directory", the staging notification is
never posted, and `waitForSingleStreamCompletion` blocks forever until it
receives a failure notification, leaving the download in an error state.

## What Changes

- **Synchronously copy the temp file inside the delegate method** before
  returning. The copy is a local disk-to-disk operation (~0 ms) and safe to
  perform on the URLSession delegate queue (non-main background queue).
- **Move the rest of `handleCompletion` logic** (notification posting, actor
  state cleanup) into the `Task { }` as before, but now it receives the
  **copied** stable URL instead of the volatile `location` URL.
- No change to any other part of the stack — `DownloadQueueManager`,
  `FileAssemblyEngine`, and the notification-based handoff protocol remain
  intact.

## Capabilities

### Modified Capabilities
- `download-engine`: Fix temp-file race in `didFinishDownloadingTo` delegate
  by doing a synchronous `copyItem` on the delegate queue before dispatching
  the async `Task`.

## Impact

- `Downly/Engine/DownloadEngine.swift` — single surgical change inside the
  `urlSession(_:downloadTask:didFinishDownloadingTo:)` delegate method.
