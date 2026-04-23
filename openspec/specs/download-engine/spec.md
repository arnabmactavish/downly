## ADDED Requirements

### Requirement: Background session initialization
The system SHALL initialize URLSession with a background configuration identified by a stable string (e.g., `com.downly.background-session`) so that download tasks survive app suspension and termination.

#### Scenario: App killed mid-download
- **WHEN** the OS terminates the app while a download is active
- **THEN** the download task continues in the background and the system relaunches the app to deliver completion or progress callbacks

#### Scenario: Session re-association on relaunch
- **WHEN** the app relaunches after being killed
- **THEN** the system MUST reconstruct the background URLSession with the same identifier so that pending delegate callbacks are delivered

### Requirement: Delegate-based progress tracking
The system SHALL implement `URLSessionDownloadDelegate` to receive byte-count progress updates and deliver them to the UI layer at most once per 0.5 seconds.

#### Scenario: Progress update throttling
- **WHEN** `urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)` fires more than twice per second
- **THEN** the engine MUST coalesce updates and notify observers at most once per 0.5 s to avoid UI thrashing

#### Scenario: Unknown total size
- **WHEN** the server does not provide a Content-Length header
- **THEN** the engine MUST still report bytes downloaded while displaying indeterminate progress in the UI

### Requirement: Pause and Resume
The system SHALL support pausing an active download and resuming it from the last byte received, using URLSession `resumeData`.

#### Scenario: Pause stores resumeData
- **WHEN** the user pauses a download
- **THEN** `URLSessionDownloadTask.cancel(byProducingResumeData:)` MUST be called and the resulting Data blob persisted in SwiftData

#### Scenario: Resume from resumeData
- **WHEN** the user resumes a paused download and resumeData is available
- **THEN** a new download task MUST be created via `URLSession.downloadTask(withResumeData:)` so download continues from the byte offset

#### Scenario: Resume without resumeData
- **WHEN** resumeData is unavailable (e.g., server does not support resume, data expired)
- **THEN** the engine MUST restart the download from the beginning and display a user-visible indication that the download restarted

### Requirement: Error handling and retry
The system SHALL detect network errors and apply an exponential-backoff retry strategy up to 3 attempts before marking a download as failed.

#### Scenario: Transient network error retry
- **WHEN** a download task fails with a transient error (e.g., `NSURLErrorNetworkConnectionLost`)
- **THEN** the engine SHALL wait 2^attempt seconds (2 s, 4 s, 8 s) before retrying, up to 3 times

#### Scenario: Permanent error
- **WHEN** a download fails after 3 retries or with a non-retryable error (e.g., 404 HTTP status)
- **THEN** the download MUST be marked with status `.error` and the error message displayed in the UI


<!-- DELTA SPEC APPENDED DUE TO SYNC FAILURE -->

## MODIFIED Requirements

### Requirement: Background session initialization
The system SHALL initialize URLSession with a background configuration identified by a stable string (e.g., `com.downly.background-session`) so that download tasks survive app suspension, screen lock, and termination.

#### Scenario: App killed mid-download
- **WHEN** the OS terminates the app while a download is active
- **THEN** the download task continues in the background and the system relaunches the app to deliver completion or progress callbacks

#### Scenario: Session re-association on relaunch
- **WHEN** the app relaunches after being killed
- **THEN** the system MUST reconstruct the background URLSession with the same identifier so that pending delegate callbacks are delivered

#### Scenario: Screen lock does not pause downloads
- **WHEN** the device screen locks while a single-stream download is active
- **THEN** the download MUST continue transferring bytes via the background URLSession daemon without interruption

#### Scenario: Background session configuration
- **WHEN** `DownloadEngine` initializes its URLSession
- **THEN** it MUST use `URLSessionConfiguration.background(withIdentifier: "com.axoman.downly.bgdownload")`
- **AND** `isDiscretionary` MUST be set to `false`
- **AND** `sessionSendsLaunchEvents` MUST be set to `true`

#### Scenario: Background completion handler delivery
- **WHEN** the system calls `application(_:handleEventsForBackgroundURLSession:completionHandler:)` in AppDelegate
- **THEN** the completion handler MUST be stored in `DownloadEngine` and invoked inside `urlSessionDidFinishEvents(forBackgroundURLSession:)`
