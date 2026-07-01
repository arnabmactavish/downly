## MODIFIED Requirements

### Requirement: App lifecycle observation
The system SHALL observe `UIApplication.willResignActiveNotification` and `UIApplication.didBecomeActiveNotification` to track the app's foreground/background state within `DownloadEngine`. The system SHALL use `UIApplication.beginBackgroundTask` to protect the migration window so that replacement background tasks can be created before iOS suspends the process.

#### Scenario: App enters background with active foreground downloads
- **WHEN** `willResignActiveNotification` fires and there are active download tasks on the foreground session
- **THEN** the engine MUST call `UIApplication.shared.beginBackgroundTask(expirationHandler:)` before initiating migration
- **AND** the engine MUST pause each foreground task via `cancel(byProducingResumeData:)` and re-start it on the background session using the resume data
- **AND** the engine MUST call `UIApplication.shared.endBackgroundTask` only after ALL replacement background tasks have been created
- **AND** the download MUST continue without interruption from the user's perspective

#### Scenario: App enters background with no active foreground downloads
- **WHEN** `willResignActiveNotification` fires and there are no active foreground session tasks
- **THEN** the engine MUST take no action (background session tasks continue unaffected)

#### Scenario: App returns to foreground
- **WHEN** `didBecomeActiveNotification` fires
- **THEN** the engine MUST update its internal `isAppActive` state to `true`
- **AND** existing background session tasks MUST NOT be migrated (they continue as-is on the background session)

#### Scenario: Background task expiration during migration
- **WHEN** `beginBackgroundTask` expiration handler fires before all tasks are migrated
- **THEN** the engine MUST call `endBackgroundTask` to avoid termination
- **AND** any tasks not yet migrated MUST remain in their current state (the background session tasks already started will continue; un-migrated foreground tasks will be treated as interrupted on next launch)

## ADDED Requirements

### Requirement: Migration cancellation suppression
The system SHALL track download IDs that are being intentionally cancelled for session migration and suppress `NSURLErrorCancelled` errors for those IDs, preventing false error reporting to the UI.

#### Scenario: Foreground task cancelled for migration
- **WHEN** `handleError` receives `NSURLErrorCancelled` for a download ID that is in the migrating set
- **THEN** the engine MUST NOT post `.downloadTaskDidFail` notification
- **AND** the engine MUST NOT mark the download as errored
- **AND** the engine MUST remove the download ID from the migrating set after the replacement background task is successfully created

#### Scenario: User-initiated cancellation during background transition
- **WHEN** `handleError` receives `NSURLErrorCancelled` for a download ID that is NOT in the migrating set
- **THEN** the engine MUST treat it as a real cancellation and post `.downloadTaskDidFail` as normal

### Requirement: Chunked download migration on backgrounding
The system SHALL handle the case where a chunked download (running on `ChunkCoordinator`'s ephemeral session) is active when the app enters the background, by cancelling in-flight chunks and falling back to a single-stream download on the background session.

#### Scenario: Chunked download active when app backgrounds
- **WHEN** `willResignActiveNotification` fires and a chunked download is in progress via `ChunkCoordinator`
- **THEN** the engine MUST cancel all in-flight chunk tasks on the ephemeral session
- **AND** the engine MUST start a fresh single-stream download on the background session for the same URL
- **AND** any fully-completed chunk files on disk MUST be cleaned up

#### Scenario: Chunked download not active when app backgrounds
- **WHEN** `willResignActiveNotification` fires and no chunked download is active
- **THEN** no chunk-related migration action SHALL be taken
