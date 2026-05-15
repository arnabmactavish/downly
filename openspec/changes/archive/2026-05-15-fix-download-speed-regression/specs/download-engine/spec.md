## MODIFIED Requirements

### Requirement: Background session initialization
The system SHALL initialize TWO URLSessions: a foreground `URLSessionConfiguration.default` session for high-speed active downloads, and a background `URLSessionConfiguration.background(withIdentifier:)` session for resilient downloads during app suspension. The background session identifier MUST be a stable string (`com.axoman.downly.bgdownload`).

#### Scenario: App killed mid-download
- **WHEN** the OS terminates the app while a download is active on the background session
- **THEN** the download task continues in the background and the system relaunches the app to deliver completion or progress callbacks

#### Scenario: Session re-association on relaunch
- **WHEN** the app relaunches after being killed
- **THEN** the system MUST reconstruct the background URLSession with the same identifier so that pending delegate callbacks are delivered

#### Scenario: Screen lock does not pause downloads
- **WHEN** the device screen locks while a single-stream download is active
- **THEN** the engine MUST have migrated the download to the background session (via `willResignActiveNotification`), and the download MUST continue transferring bytes without interruption

#### Scenario: Background session configuration
- **WHEN** `DownloadEngine` initializes its background URLSession
- **THEN** it MUST use `URLSessionConfiguration.background(withIdentifier: "com.axoman.downly.bgdownload")`
- **AND** `isDiscretionary` MUST be set to `false`
- **AND** `sessionSendsLaunchEvents` MUST be set to `true`

#### Scenario: Foreground session configuration
- **WHEN** `DownloadEngine` initializes its foreground URLSession
- **THEN** it MUST use `URLSessionConfiguration.default`
- **AND** `httpMaximumConnectionsPerHost` MUST be set to `6`

#### Scenario: Background completion handler delivery
- **WHEN** the system calls `application(_:handleEventsForBackgroundURLSession:completionHandler:)` in AppDelegate
- **THEN** the completion handler MUST be stored in `DownloadEngine` and invoked inside `urlSessionDidFinishEvents(forBackgroundURLSession:)`

## REMOVED Requirements

### Requirement: Chunk download via background session
**Reason**: The `startChunkDownload()` method on `DownloadEngine` is dead code — `ChunkCoordinator` uses its own ephemeral session and never calls this method. The method also has a correctness bug (overwrites `activeTasks` entries keyed by `downloadID` rather than per-chunk, so only the last chunk would have a valid progress continuation).
**Migration**: No migration needed. `ChunkCoordinator` already handles all chunk downloads independently with its own ephemeral `URLSession`.
