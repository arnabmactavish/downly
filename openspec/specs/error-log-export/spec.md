## ADDED Requirements

### Requirement: Error detail view on tap
The system SHALL present a detail sheet when the user taps on a download card that is in `.error` state, displaying the full error message string.

#### Scenario: Tap errored card shows error detail sheet
- **WHEN** the user taps a download card with status `.error`
- **THEN** a `.sheet` MUST be presented containing the full `errorMessage` string, the download file name, and the timestamp of the error

#### Scenario: Error detail sheet with empty error message
- **WHEN** the error detail sheet is presented and `errorMessage` is `nil` or empty
- **THEN** the sheet MUST display a generic fallback message: "An unknown error occurred"

### Requirement: Copy error message
The system SHALL provide a "Copy" button in the error detail sheet that copies the full error string to the system clipboard.

#### Scenario: Copy button copies to clipboard
- **WHEN** the user taps the "Copy" button in the error detail sheet
- **THEN** the full error message MUST be copied to `UIPasteboard.general.string`
- **AND** a brief confirmation (e.g., haptic feedback or toast) MUST be shown

### Requirement: Share error message
The system SHALL provide a "Share" button in the error detail sheet that opens the iOS share sheet with the error message as text content.

#### Scenario: Share button opens share sheet
- **WHEN** the user taps the "Share" button in the error detail sheet
- **THEN** a `UIActivityViewController` (or SwiftUI `ShareLink`) MUST be presented with the error message string as the shared content

#### Scenario: Share content includes context
- **WHEN** the share sheet is invoked
- **THEN** the shared text MUST include the file name, URL, and error message formatted as a readable report
