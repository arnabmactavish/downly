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
