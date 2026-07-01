## Requirements

### Requirement: Tap opens download detail bottom sheet
Tapping any download card SHALL present a bottom sheet with detailed download information.

#### Scenario: Tap on any download state
- **WHEN** user taps a download card in any state (running, paused, completed, error, pending)
- **THEN** a bottom sheet SHALL present at `.medium` detent with option to drag to `.large`

#### Scenario: Medium detent content
- **WHEN** the detail sheet presents at medium height
- **THEN** it SHALL display: file name, full URL (truncated with expand option), file size, downloaded size, progress percentage, current status, created date, and action buttons relevant to the state

#### Scenario: Large detent content
- **WHEN** user drags the sheet to large/full height
- **THEN** it SHALL additionally display: speed history graph (for running/paused), chunk progress breakdown (if chunked download), error details (if error state), and file location (if completed)

### Requirement: Speed history graph
The detail sheet SHALL display a real-time speed graph for active downloads.

#### Scenario: Running download graph
- **WHEN** the detail sheet is open for a `.running` download
- **THEN** a Swift Charts `AreaMark` graph SHALL display the last 60 seconds of download speed, updating every second, with a gradient fill matching the status accent color

#### Scenario: Paused download graph
- **WHEN** the detail sheet is open for a `.paused` download
- **THEN** the graph SHALL display the speed history from before the pause with a "Paused" overlay, frozen at the last recorded state

#### Scenario: No graph for pending/completed
- **WHEN** the detail sheet is open for a `.pending` or `.completed` download
- **THEN** no speed graph SHALL be displayed; the space SHALL be used for additional metadata instead

### Requirement: Animated progress visualization
The detail sheet SHALL include an animated progress indicator beyond the standard progress bar.

#### Scenario: Active download animation
- **WHEN** viewing detail sheet for a `.running` download
- **THEN** a circular progress ring with animated gradient stroke SHALL display the completion percentage with smooth animation on updates

#### Scenario: Completed download animation
- **WHEN** viewing detail sheet for a `.completed` download
- **THEN** a static filled circle with checkmark SHALL display, with a celebratory particle/confetti animation on first open

### Requirement: Detail sheet action buttons
The detail sheet SHALL include contextual action buttons at the bottom.

#### Scenario: Running download actions
- **WHEN** viewing detail sheet for a `.running` download
- **THEN** action buttons SHALL include: Pause, Cancel

#### Scenario: Paused download actions
- **WHEN** viewing detail sheet for a `.paused` download
- **THEN** action buttons SHALL include: Resume, Update URL, Cancel

#### Scenario: Error download actions
- **WHEN** viewing detail sheet for a `.error` download
- **THEN** action buttons SHALL include: Retry, Update URL, Copy Error, Delete

#### Scenario: Completed download actions
- **WHEN** viewing detail sheet for a `.completed` download
- **THEN** action buttons SHALL include: Open File, Share File

### Requirement: Tap replaces error-only tap behavior
The universal tap-to-detail-sheet behavior SHALL replace the existing error-only `onTapGesture` that shows `ErrorDetailSheet`.

#### Scenario: Error state tap now opens detail sheet
- **WHEN** user taps a download card in `.error` state
- **THEN** the download detail sheet SHALL present (not the legacy `ErrorDetailSheet`), with error details integrated into the detail sheet's content
