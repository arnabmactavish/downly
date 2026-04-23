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
