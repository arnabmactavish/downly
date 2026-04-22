## 1. DownlyLogger — Debug Logging Utility

- [x] 1.1 Create `Downly/App/DownlyLogger.swift` — define a `DownlyLogger` enum/struct with an `os.Logger` property using subsystem `"com.axoman.downly"` and category `"downloads"`. Add static methods: `logStart(id:url:)`, `logProgress(id:bytesWritten:totalBytes:speed:)`, `logCompletion(id:path:)`, `logError(id:error:)`. Each wraps an `os.Logger` call plus a `#if DEBUG` `print("[Downly] …")` line.

## 2. Fix DownloadEngine — Session and Staging Path

- [x] 2.1 In `DownloadEngine.init()`, replace `URLSessionConfiguration.background(withIdentifier:)` with `URLSessionConfiguration.default`.
- [x] 2.2 Fix `handleCompletion` to stage into App Group container `tmp/` subfolder.
- [x] 2.3 Add `DownlyLogger.logStart(id:url:)` call at the end of `startDownload(id:url:resumeData:)`.
- [x] 2.4 Add `DownlyLogger.logProgress(...)` call at the end of `handleProgress` (after throttle gate).
- [x] 2.5 Add `DownlyLogger.logCompletion(id:path:)` call in `handleCompletion` success branch.
- [x] 2.6 Add `DownlyLogger.logError(id:error:)` calls inside `handleError` on retry and permanent-fail paths.

## 3. Fix DownloadQueueManager — Progress Wiring and Destination

- [x] 3.1 Wire `DownloadProgressCoordinator` into single-stream path in `executeDownload`.
- [x] 3.2 Wire `DownloadProgressCoordinator` into fallback single-stream path.
- [x] 3.3 Replace `documentsURL(fileName:)` to use App Group container `Documents/` with auto-creation.
- [x] 3.4 All call sites of `documentsURL(fileName:)` verified — no signature change needed (non-throwing).

## 4. Info.plist — Files App Visibility

- [x] 4.1 Open `Downly/Info.plist` and add `UIFileSharingEnabled = YES` and `LSSupportsOpeningDocumentsInPlace = YES`.

## 5. Verification

- [x] 5.1 Build the app in the Simulator (Debug configuration). BUILD SUCCEEDED — zero errors.
- [x] 5.2 Run the app and verify `[Downly]` log lines appear in Xcode console during a download.
- [x] 5.3 After download completes, verify file exists in App Group container Documents/ path.
- [x] 5.4 On a physical device, open Files app → On My iPhone → Downly. Verify file appears.
- [x] 5.5 Confirm `totalSize` and `downloadedSize` are non-zero in the UI during an active download.
- [x] 5.6 Confirm speed is displayed in the download card UI during an active download.
