## MODIFIED Requirements

### Requirement: Background session initialization
The system SHALL initialize URLSession with a **default** (foreground) configuration. The background session identifier is reserved for a future background-transfer capability. The engine MUST NOT use `URLSessionConfiguration.background(withIdentifier:)` for download tasks.

#### Scenario: Download tasks started with default session
- **WHEN** `DownloadEngine.startDownload(id:url:resumeData:)` is called
- **THEN** the task MUST be issued on a `URLSessionConfiguration.default`-based session that delivers `URLSessionDownloadDelegate` callbacks while the app is in the foreground

#### Scenario: Delegate progress callbacks received
- **WHEN** the server sends data and the session is a default session
- **THEN** `urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)` MUST fire with non-zero byte counts

#### Scenario: App Group container used for stable staging
- **WHEN** `urlSession(_:downloadTask:didFinishDownloadingTo:)` fires
- **THEN** `DownloadEngine.handleCompletion` MUST copy the temp file to the App Group container's `tmp/` subfolder (not `FileManager.default.temporaryDirectory`) using the download UUID as the filename with a `.tmp` extension

## ADDED Requirements

### Requirement: Debug session logging
The engine SHALL emit download lifecycle log entries in DEBUG builds using `DownlyLogger`.

#### Scenario: Start logged in debug
- **WHEN** `startDownload(id:url:resumeData:)` is called in a DEBUG build
- **THEN** a log line containing the download UUID and URL MUST appear in the Xcode console

#### Scenario: Progress logged in debug
- **WHEN** a progress callback fires and is throttled through to `handleProgress` in a DEBUG build
- **THEN** a log line with bytes written, total bytes, and computed speed MUST appear in the Xcode console

#### Scenario: Completion logged in debug
- **WHEN** `handleCompletion` fires in a DEBUG build
- **THEN** a log line with the download UUID and stable file path MUST appear in the Xcode console

#### Scenario: Error logged in debug
- **WHEN** `handleError` fires in a DEBUG build
- **THEN** a log line with the download UUID and error description MUST appear in the Xcode console

#### Scenario: No print output in release
- **WHEN** the app is compiled in RELEASE configuration
- **THEN** no `print()` or equivalent console output MUST be emitted from the download engine
