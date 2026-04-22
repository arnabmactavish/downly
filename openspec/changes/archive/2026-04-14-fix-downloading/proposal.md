## Why

Downloads are completely broken: no file is saved to disk, file size never appears, progress is always 0%, speed is not shown, and the app's folder is invisible in the Files app. The root causes are architectural — the URLSession background session conflicts with chunk downloads, the destination directory is not exposed to iOS Files app, progress updates never reach the UI, and there is no debug logging to diagnose failures.

## What Changes

- **Fix file destination**: Save completed downloads to the iOS Files-exposed `Documents` directory inside the App Group container (currently saves to the wrong path that Files cannot see).
- **Fix background URLSession conflict**: `ChunkCoordinator` and `ChunkManager` use ephemeral sessions for HEAD/chunk requests, but `DownloadEngine` registers a `background` URLSession. The chunked path uses ephemeral sessions correctly, but single-stream downloads go through the background session which requires the app to be configured as a true background transfer client — and in the simulator/foreground this causes tasks to never deliver delegate callbacks.
- **Fix progress not reaching UI**: `DownloadProgressCoordinator` is instantiated but never wired into `DownloadQueueManager.executeDownload()`. Progress stream emissions are never observed, so `DownloadItem.downloadedSize` / `totalSize` are never updated with live values from the stream.
- **Fix size display**: `totalSize` is persisted after the HEAD request, but UI reading happens on the main context which may not have received the save notification.
- **Fix Files app visibility**: Add `UIFileSharingEnabled` (`Application supports iTunes file sharing`) and `LSSupportsOpeningDocumentsInPlace` keys to `Info.plist` so the app's Documents folder appears in the iOS Files app.
- **Fix single-stream temp file handoff**: `handleCompletion` in `DownloadEngine` copies a temp file to `FileManager.default.temporaryDirectory` which iOS purges aggressively. The subsequent `moveItem` call in `waitForSingleStreamCompletion` fails silently because the file is gone.
- **Add debug logging**: Introduce a `DownlyLogger` utility using `os.Logger` (production-safe subsystem) with `#if DEBUG` console print statements for download lifecycle events (start, progress, speed, error, completion).

## Capabilities

### New Capabilities
- `download-debug-logging`: Structured `os.Logger`-backed logging for download lifecycle events, visible only in `#if DEBUG` builds via Xcode console output.

### Modified Capabilities
- `download-engine`: Fix temp-file handoff to use a stable staging directory; switch single-stream downloads to a foreground-compatible URLSession; add debug log hooks.
- `download-queue`: Wire `DownloadProgressCoordinator` into `executeDownload`; fix destination URL to use app-accessible Documents directory with Files app visibility.
- `download-engine-file-handoff`: Fix stable temp path to survive iOS temporary directory purges.

## Impact

- `Downly/Engine/DownloadEngine.swift` — session configuration fix, temp handoff path fix, logging hooks
- `Downly/Queue/DownloadQueueManager.swift` — destination URL fix, progress coordinator wiring
- `Downly/Queue/DownloadProgressCoordinator.swift` — verify it is created and observed per download in the queue
- `Downly/Info.plist` — add `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`
- `Downly/App/DownlyLogger.swift` (**new**) — `os.Logger` wrapper with `#if DEBUG` console print sink
