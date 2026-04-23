## ADDED Requirements

### Requirement: Estimated time remaining display
The download item card SHALL display a human-readable estimated time remaining (ETA) when the download is in `.running` state and the speed is greater than zero.

#### Scenario: ETA shown during active download
- **WHEN** a download card is displayed with `status == .running` and `speedBytesPerSecond > 0` and `totalSize > 0`
- **THEN** the card MUST display the estimated time remaining in a human-readable format (e.g., "~2 min remaining", "~30 sec remaining", "~1 hr 15 min remaining")

#### Scenario: ETA hidden when speed is zero
- **WHEN** a download card is displayed with `status == .running` but `speedBytesPerSecond == 0`
- **THEN** the card MUST NOT display an ETA label (to avoid showing "∞" or misleading values)

#### Scenario: ETA hidden for completed/paused/error states
- **WHEN** a download card is displayed with status other than `.running`
- **THEN** no ETA label SHALL be shown

### Requirement: ETA persistence to SwiftData
The `DownloadItem` model SHALL persist an `estimatedSecondsRemaining: Int?` property, updated via the `DownloadProgressCoordinator` throttle alongside other progress fields.

#### Scenario: ETA persisted on progress update
- **WHEN** a `DownloadProgress` event is processed by `DownloadProgressCoordinator`
- **THEN** the `estimatedSecondsRemaining` value from the progress snapshot MUST be persisted to the `DownloadItem` model

#### Scenario: ETA cleared on completion or error
- **WHEN** a download transitions to `.completed` or `.error`
- **THEN** `estimatedSecondsRemaining` MUST be set to `nil`

### Requirement: ETA formatting
The ETA MUST be formatted using appropriate time units with rounding.

#### Scenario: Less than 60 seconds
- **WHEN** `estimatedSecondsRemaining` is less than 60
- **THEN** the display MUST show "~N sec remaining"

#### Scenario: Between 1 and 60 minutes
- **WHEN** `estimatedSecondsRemaining` is between 60 and 3599
- **THEN** the display MUST show "~N min remaining"

#### Scenario: 60 minutes or more
- **WHEN** `estimatedSecondsRemaining` is 3600 or more
- **THEN** the display MUST show "~N hr M min remaining"
