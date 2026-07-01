## MODIFIED Requirements

### Requirement: Download item card
Each download in the list SHALL be displayed as a card showing: file name, total size, downloaded size, remaining size, progress percentage, current speed, estimated time remaining, and a status indicator. The card SHALL support swipe, tap, long press, and multi-select gestures.

#### Scenario: Downloading state card
- **WHEN** a download is in `.running` state with `downloadedSize > 0`
- **THEN** the card MUST show an animated progress bar, live-updating speed (e.g., "4.2 MB/s"), and estimated time remaining (e.g., "~2 min remaining")

#### Scenario: Paused state card
- **WHEN** a download is in `.paused` state
- **THEN** the card MUST display a dimmed appearance with a "Paused" label and a resume button

#### Scenario: Completed state card
- **WHEN** a download is in `.completed` state
- **THEN** the card MUST display a green checkmark success indicator and the final file size, with no progress bar

#### Scenario: Error state card
- **WHEN** a download is in `.error` state
- **THEN** the card MUST display a red error indicator, a shortened error message, and a "Retry" button

#### Scenario: Tap opens detail sheet
- **WHEN** user taps any download card
- **THEN** a detail bottom sheet SHALL present with comprehensive download information (replaces error-only tap behavior)

#### Scenario: Long press shows context menu
- **WHEN** user long presses any download card
- **THEN** a context menu SHALL appear with state-appropriate actions

#### Scenario: Left swipe reveals delete
- **WHEN** user swipes left on any download card
- **THEN** a destructive delete action SHALL be revealed

#### Scenario: Selection mode appearance
- **WHEN** the list is in selection mode (via two-finger gesture or Edit button)
- **THEN** each card SHALL show a leading selection checkbox and support tap-to-toggle selection
