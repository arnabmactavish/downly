## ADDED Requirements

### Requirement: Max concurrent downloads
The system SHALL limit simultaneously active downloads to a maximum of 3 using an OperationQueue with `maxConcurrentOperationCount = 3`.

#### Scenario: Queue at capacity
- **WHEN** 3 downloads are already active and the user adds a 4th
- **THEN** the 4th download MUST enter the `.pending` state and automatically start when one of the active downloads completes, is paused, or errors

#### Scenario: Auto-start from queue
- **WHEN** an active download finishes (completes or errors) and there are pending downloads in the queue
- **THEN** the next pending download MUST be automatically dequeued and started without user interaction

### Requirement: Download state machine
Each download MUST transition through a well-defined set of states: `pending → running → paused / completed / error`. Invalid state transitions MUST be rejected.

#### Scenario: Valid transitions
- **WHEN** a running download is paused by the user
- **THEN** its state SHALL transition to `.paused` and the OperationQueue operation SHALL be suspended

#### Scenario: Resuming a paused download
- **WHEN** the user resumes a download in `.paused` state
- **THEN** its state SHALL transition to `.running` and the download task SHALL resume from the stored byte offset

#### Scenario: Invalid transition rejected
- **WHEN** code attempts to transition a `.completed` download to `.running`
- **THEN** the transition MUST be rejected and logged as a programmer error

### Requirement: Download cancellation
The system SHALL allow the user to cancel a download from any non-completed state, removing it from the queue and cleaning up associated resources.

#### Scenario: Cancel active download
- **WHEN** the user cancels a `.running` download
- **THEN** the download task(s) MUST be cancelled, all associated temp files deleted, the SwiftData record updated to reflect cancellation, and the item removed from the UI

#### Scenario: Cancel pending download
- **WHEN** the user cancels a `.pending` download
- **THEN** the download MUST be removed from the OperationQueue before it starts and its SwiftData record deleted

### Requirement: Queue persistence across launches
The system SHALL restore the full queue state on app relaunch using SwiftData, re-queueing pending and interrupted downloads.

#### Scenario: Re-queuing on launch
- **WHEN** the app launches and SwiftData contains downloads in `.pending` or `.interrupted` state
- **THEN** these downloads MUST be placed back into the OperationQueue in their original priority order

### Requirement: Update download URL API
`DownloadQueueManager` SHALL expose an `updateURL(id:newURL:)` async throws method that validates the new URL and updates the download record.

#### Scenario: Successful URL update
- **WHEN** `updateURL(id: downloadID, newURL: validURL)` is called for a download in `.paused` or `.error` state and the HEAD request confirms range support and compatible content length
- **THEN** the `DownloadItem.url` SHALL be updated, `resumeData` SHALL be cleared, incomplete chunk records SHALL have their status reset, and the download status SHALL be set to `.paused`

#### Scenario: Update URL on running download
- **WHEN** `updateURL` is called for a download in `.running` state
- **THEN** the method SHALL throw `DownloadQueueError.downloadMustBePaused`

#### Scenario: Update URL with incompatible server
- **WHEN** `updateURL` is called and the HEAD request fails or returns no range support
- **THEN** the method SHALL throw `DownloadQueueError.urlNotCompatible(reason:)` with a descriptive reason string

#### Scenario: Update URL with size mismatch but user accepts fresh start
- **WHEN** the HEAD response shows `Content-Length` < current `downloadedSize` and the caller passes `resetProgress: true`
- **THEN** the `DownloadItem` SHALL be updated with the new URL, `downloadedSize` reset to 0, all chunk records deleted, and status set to `.pending`

