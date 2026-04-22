## Root Cause

`URLSessionDownloadDelegate.urlSession(_:downloadTask:didFinishDownloadingTo:)`
provides a `location: URL` that is **only valid synchronously** inside the
delegate callback. The current implementation dispatches `handleCompletion` into
a Swift `Task { }`, causing the copy attempt to happen after iOS has already
deleted the temporary file.

## Fix Strategy

Perform a **synchronous `FileManager.copyItem`** on the delegate queue (before
the method returns), producing a stable URL in the App Group `tmp/` directory.
Only then dispatch the `Task { }` to do actor-isolated state cleanup and post
the completion notification — passing the now-stable URL.

### Before

```swift
nonisolated func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
) {
    guard let desc = downloadTask.taskDescription else { return }
    let parts = desc.split(separator: "|")
    guard let downloadID = UUID(uuidString: String(parts[0])) else { return }
    let chunkIndex = parts.count > 1 ? Int(parts[1]) : nil
    Task {
        await self.handleCompletion(          // ← runs after delegate returns
            downloadID: downloadID,           //   temp file is already gone
            chunkIndex: chunkIndex,
            tempLocation: location            // ← stale URL
        )
    }
}
```

### After

```swift
nonisolated func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
) {
    guard let desc = downloadTask.taskDescription else { return }
    let parts = desc.split(separator: "|")
    guard let downloadID = UUID(uuidString: String(parts[0])) else { return }
    let chunkIndex = parts.count > 1 ? Int(parts[1]) : nil

    // ── Synchronous copy while the delegate is still on the call stack ──
    // iOS deletes `location` the moment this method returns, so we must
    // copy it to a stable path NOW, on the delegate's background queue.
    let fm = FileManager.default
    guard let appGroupURL = fm.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.axoman.downly"
    ) else {
        Task {
            await self.postFailure(downloadID: downloadID, message: "App Group unavailable")
        }
        return
    }
    let stagingDir = appGroupURL.appendingPathComponent("tmp", isDirectory: true)
    let stableURL = stagingDir.appendingPathComponent("\(downloadID.uuidString).tmp")

    do {
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: stableURL.path) {
            try fm.removeItem(at: stableURL)
        }
        try fm.copyItem(at: location, to: stableURL)   // ← synchronous, safe
    } catch {
        Task {
            await self.postFailure(downloadID: downloadID, message: error.localizedDescription)
        }
        return
    }

    // ── Async continuation uses the now-stable URL ──
    Task {
        await self.handleCompletion(
            downloadID: downloadID,
            chunkIndex: chunkIndex,
            stableLocation: stableURL          // ← file guaranteed to exist
        )
    }
}
```

`handleCompletion` is simplified — it no longer needs to copy the file (it
already exists at `stableLocation`); it only posts the notification and cleans
up actor state.

## Files Changed

| File | Change |
|---|---|
| `Downly/Engine/DownloadEngine.swift` | Move `copyItem` sync inside delegate; simplify `handleCompletion` |
