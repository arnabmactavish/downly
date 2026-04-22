## MODIFIED Requirements

### Requirement: Max concurrent downloads
The system SHALL limit simultaneously active downloads to a maximum of 3 using an OperationQueue with `maxConcurrentOperationCount = 3`.

#### Scenario: Queue at capacity
- **WHEN** 3 downloads are already active and the user adds a 4th
- **THEN** the 4th download MUST enter the `.pending` state and automatically start when one of the active downloads completes, is paused, or errors

#### Scenario: Auto-start from queue
- **WHEN** an active download finishes (completes or errors) and there are pending downloads in the queue
- **THEN** the next pending download MUST be automatically dequeued and started without user interaction

## ADDED Requirements

### Requirement: Progress coordinator wired per download
`DownloadQueueManager` SHALL instantiate a `DownloadProgressCoordinator` for each active single-stream download and observe the `ProgressStream` returned by `DownloadEngine.startDownload()`, so that `DownloadItem.downloadedSize`, `totalSize`, and speed are updated in SwiftData while the download is running.

#### Scenario: downloadedSize updates during download
- **WHEN** a single-stream download is running and progress callbacks arrive from URLSession
- **THEN** `DownloadItem.downloadedSize` in SwiftData MUST be updated at least once per 2 seconds to reflect bytes received

#### Scenario: totalSize updated after HEAD request
- **WHEN** `chunkManager.analyzeServer()` returns a `contentLength`
- **THEN** `DownloadItem.totalSize` MUST be persisted to SwiftData before the first progress callback fires

#### Scenario: Speed available to UI
- **WHEN** a download is in-progress and at least 1 second has elapsed since the last speed sample
- **THEN** the `DownloadProgress.speed` value (bytes/sec) MUST be non-zero and accessible to the UI via the progress coordinator

### Requirement: Files-app-visible destination directory
The system SHALL save completed downloads to a directory visible in the iOS Files app.

#### Scenario: Completed file appears in Files app
- **WHEN** a download completes successfully
- **THEN** the file MUST be accessible from the iOS Files app under the Downly application folder

#### Scenario: Destination uses App Group Documents
- **WHEN** `documentsURL(fileName:)` is called inside `DownloadQueueManager`
- **THEN** the returned URL MUST resolve to `<AppGroupContainer>/Documents/<fileName>`, not the app-sandbox `Documents/` directory

#### Scenario: Destination directory created if absent
- **WHEN** the App Group container's `Documents/` subdirectory does not exist
- **THEN** `DownloadQueueManager` MUST create it with intermediate directories before attempting to move the file
