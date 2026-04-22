## MODIFIED Requirements

### Requirement: Live Activity start on download begin
The system SHALL start an ActivityKit Live Activity when a download transitions to `.running` state, if the device supports Live Activities AND the user preference `liveActivitiesEnabled` is `true`.

#### Scenario: Live Activity creation — single-stream download
- **WHEN** a single-stream download starts (non-chunked path) and Live Activities are supported and `liveActivitiesEnabled` is `true`
- **THEN** `LiveActivityManager.startActivity(for:)` MUST be called before `engine.startDownload` so that the activity handle exists before the first progress update is delivered

#### Scenario: Live Activity creation — chunked download
- **WHEN** a chunked download starts and Live Activities are supported and `liveActivitiesEnabled` is `true`
- **THEN** `LiveActivityManager.startActivity(for:)` MUST be called before `ChunkCoordinator.downloadAll` begins

#### Scenario: Live Activity not duplicated on resume
- **WHEN** a download is resumed and a Live Activity for the same download ID already exists in `LiveActivityManager`
- **THEN** `startActivity` MUST be a no-op (guard `activities[id] == nil` before calling `Activity.request`)

#### Scenario: Unsupported device graceful degradation
- **WHEN** `ActivityAuthorizationInfo().areActivitiesEnabled` returns `false`
- **THEN** no ActivityKit call SHALL be made and the download proceeds normally without Live Activity

#### Scenario: User preference disabled
- **WHEN** `UserDefaults.standard.bool(forKey: "liveActivitiesEnabled")` returns `false`
- **THEN** `LiveActivityManager.startActivity(for:)` MUST return without creating an activity

### Requirement: Live Activity periodic updates
The system SHALL push content updates to the Live Activity at most once every 2 seconds during an active download, for both single-stream and chunked downloads.

#### Scenario: Progress update pushed — single-stream
- **WHEN** a single-stream download is active and 2 seconds have elapsed since the last Live Activity update
- **THEN** `activity.update(using:)` MUST be called with current progress percentage, download speed (bytes/s), and estimated time remaining via `DownloadProgressCoordinator`

#### Scenario: Progress update pushed — chunked
- **WHEN** a chunk completes and `item.downloadedSize` / `item.totalSize` produces a valid percentage
- **THEN** `LiveActivityManager.updateActivity(id:state:)` MUST be called with the synthesised percentage and zero speed (ETA unknown for chunked path)

#### Scenario: Content update fields
- **WHEN** a Live Activity content update is sent
- **THEN** it MUST include: `fileName` (String), `progressPercent` (Double 0–100), `speedBytesPerSecond` (Int64), `estimatedSecondsRemaining` (Int?), `status` (DownloadStatus)

### Requirement: Live Activity end on completion or failure
The system SHALL end the Live Activity when a download completes or permanently fails.

#### Scenario: Completion
- **WHEN** a download's status transitions to `.completed`
- **THEN** `activity.end(using:dismissalPolicy:)` MUST be called with `.after(.now + 5)` so the final completion state is briefly visible

#### Scenario: Failure
- **WHEN** a download's status transitions to `.error`
- **THEN** `activity.end(using:dismissalPolicy:)` MUST be called with `.immediate`

#### Scenario: Multiple downloads
- **WHEN** multiple downloads are running simultaneously
- **THEN** each MUST have its own independent Live Activity instance showing its own progress

### Requirement: ActivityKit attributes definition
The system SHALL define `DownloadAttributes: ActivityAttributes` with `ContentState` carrying all mutable progress fields.

#### Scenario: Attributes separation
- **WHEN** `DownloadAttributes` is defined
- **THEN** static fields (e.g., `fileName`, `downloadID`) MUST be in `DownloadAttributes` and mutable fields (progress, speed, ETA, status) MUST be in `DownloadAttributes.ContentState`
