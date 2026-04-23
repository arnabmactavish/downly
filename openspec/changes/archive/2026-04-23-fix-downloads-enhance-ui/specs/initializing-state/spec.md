## ADDED Requirements

### Requirement: Initializing state visual indicator
When a download is freshly enqueued and no bytes have been received yet, the download card SHALL display an "Initializing…" label and an indeterminate shimmer animation instead of the normal progress bar and byte counts.

#### Scenario: Initializing state detection
- **WHEN** a download card is displayed with `status == .running` and `downloadedSize == 0` and `totalSize == 0`
- **THEN** the card MUST show the text "Initializing…" in place of the byte count stats row

#### Scenario: Shimmer animation on progress bar
- **WHEN** the download is in the initializing state
- **THEN** the progress bar area MUST display a smooth, horizontally-sweeping shimmer/gradient animation to indicate activity

#### Scenario: Transition to normal progress
- **WHEN** the first progress update arrives (either `downloadedSize > 0` or `totalSize > 0`)
- **THEN** the card MUST smoothly animate from the initializing state to the normal progress display with a spring animation

### Requirement: Pending state shows initializing
When a download is in `.pending` state (queued but not yet started by the operation queue), the card SHALL show "Waiting…" instead of byte counts.

#### Scenario: Pending state display
- **WHEN** a download card is displayed with `status == .pending`
- **THEN** the card MUST show "Waiting…" text and a subtle pulsing animation on the status dot

#### Scenario: Pending to running transition
- **WHEN** a pending download transitions to `.running`
- **THEN** the card MUST animate the text change from "Waiting…" to "Initializing…" or directly to the progress display
