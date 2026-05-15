## ADDED Requirements

### Requirement: Foreground session for active downloads
The system SHALL maintain a foreground `URLSessionConfiguration.default` session that is used for all new single-stream downloads when the app is in the foreground, providing maximum download throughput.

#### Scenario: New download while app is in foreground
- **WHEN** a new single-stream download is started and the app is in the active/foreground state
- **THEN** the download task MUST be created on the foreground `URLSession` (not the background session)
- **AND** progress delegate callbacks MUST be delivered to `DownloadEngine` as before

#### Scenario: New download while app is in background
- **WHEN** a new single-stream download is started and the app is NOT in the active state (e.g., queued during background launch or restore)
- **THEN** the download task MUST be created on the background `URLSession` to ensure it survives suspension

### Requirement: App lifecycle observation
The system SHALL observe `UIApplication.willResignActiveNotification` and `UIApplication.didBecomeActiveNotification` to track the app's foreground/background state within `DownloadEngine`.

#### Scenario: App enters background with active foreground downloads
- **WHEN** `willResignActiveNotification` fires and there are active download tasks on the foreground session
- **THEN** the engine MUST pause each foreground task via `cancel(byProducingResumeData:)` and re-start it on the background session using the resume data
- **AND** the download MUST continue without interruption from the user's perspective

#### Scenario: App enters background with no active foreground downloads
- **WHEN** `willResignActiveNotification` fires and there are no active foreground session tasks
- **THEN** the engine MUST take no action (background session tasks continue unaffected)

#### Scenario: App returns to foreground
- **WHEN** `didBecomeActiveNotification` fires
- **THEN** the engine MUST update its internal `isAppActive` state to `true`
- **AND** existing background session tasks MUST NOT be migrated (they continue as-is on the background session)

### Requirement: Resume data unavailable during migration
The system SHALL handle the case where resume data is not available when migrating a foreground task to background.

#### Scenario: Server does not support resume
- **WHEN** the engine attempts to pause a foreground task for migration and resume data is `nil`
- **THEN** the engine MUST start a fresh download task on the background session from the beginning
- **AND** the download progress MUST reset to 0 for that task

### Requirement: Active task session tracking
The system SHALL track which session (foreground or background) each active download task is running on.

#### Scenario: Task session identification
- **WHEN** a delegate callback fires for any download task
- **THEN** the engine MUST correctly identify the download ID and route the callback to the appropriate handler regardless of which session the task belongs to
