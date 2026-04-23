## MODIFIED Requirements

### Requirement: Live Activity end on completion or failure
The system SHALL end the Live Activity when a download completes, permanently fails, OR is cancelled by the user.

#### Scenario: Completion
- **WHEN** a download's status transitions to `.completed`
- **THEN** `activity.end(using:dismissalPolicy:)` MUST be called with `.after(.now + 5)` so the final completion state is briefly visible

#### Scenario: Failure
- **WHEN** a download's status transitions to `.error`
- **THEN** `activity.end(using:dismissalPolicy:)` MUST be called with `.immediate`

#### Scenario: Cancellation
- **WHEN** the user cancels a download via `cancelDownload(id:)` or via the edit mode bulk delete
- **THEN** `LiveActivityManager.endActivity(id:, policy: .immediate)` MUST be called to dismiss the Live Activity immediately
- **AND** the activity handle and throttle timestamp MUST be removed from `LiveActivityManager`'s internal dictionaries

#### Scenario: Multiple downloads
- **WHEN** multiple downloads are running simultaneously
- **THEN** each MUST have its own independent Live Activity instance showing its own progress
