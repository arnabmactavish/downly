## MODIFIED Requirements

### Requirement: Download item card
Each download in the list SHALL be displayed as a card showing: file name, total size, downloaded size, remaining size, progress percentage, current speed, estimated time remaining, and a status indicator.

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
- **AND** the card MUST be tappable to present an error detail sheet

## REMOVED Requirements

### Requirement: Settings "Done" button in toolbar
**Reason**: Settings is now displayed as a tab in `MainTabView`, not as a modal sheet. The "Done" dismiss button is unnecessary and confusing.
**Migration**: Remove the `ToolbarItem(placement: .topBarTrailing)` containing `Button("Done") { dismiss() }` from `SettingsView`. The `@Environment(\.dismiss)` property can also be removed since it is no longer used.
