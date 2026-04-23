## ADDED Requirements

### Requirement: Leading selection checkboxes in edit mode
When edit mode is active, a selection checkbox SHALL appear at the leading edge of each download card, and the card content SHALL shift to the right with animation.

#### Scenario: Checkbox appears with animation
- **WHEN** the user activates edit mode
- **THEN** each download card MUST animate rightward (via leading padding) and a circular checkbox MUST appear in the revealed leading space

#### Scenario: Checkbox toggle selection
- **WHEN** the user taps a checkbox
- **THEN** the checkbox MUST toggle between empty circle (`circle`) and filled checkmark (`checkmark.circle.fill`) with accent color
- **AND** the corresponding download ID MUST be added to or removed from the selection set

#### Scenario: Card shift distance
- **WHEN** edit mode is active
- **THEN** each card MUST have approximately 40pt of leading padding to accommodate the checkbox, animated with a spring animation

### Requirement: Floating delete button in bottom-right corner
When edit mode is active and at least one item is selected, a floating circular delete button SHALL appear pinned to the bottom-right corner of the screen.

#### Scenario: Delete FAB visibility
- **WHEN** edit mode is active and `selectedIDs` is not empty
- **THEN** a floating circular button with a trash icon SHALL be visible in the bottom-right corner of the screen, above the tab bar safe area

#### Scenario: Delete FAB hidden when no selection
- **WHEN** edit mode is active but no items are selected
- **THEN** the delete FAB MUST be hidden or disabled (visually dimmed)

#### Scenario: Delete FAB action
- **WHEN** the user taps the delete FAB
- **THEN** all downloads whose IDs are in `selectedIDs` MUST be cancelled and removed via `cancelDownload(id:)`
- **AND** the selection set MUST be cleared
- **AND** edit mode MUST remain active (allowing further selections)

#### Scenario: Delete FAB appearance
- **WHEN** the delete FAB is rendered
- **THEN** it MUST be a 56pt circle with a red/error tinted background and white trash icon, with a shadow for elevation

### Requirement: Edit button transforms to close icon
The "Edit" toolbar button SHALL change to a close icon ("✕") during edit mode, acting as a cancel/done toggle.

#### Scenario: Edit button in normal mode
- **WHEN** edit mode is NOT active
- **THEN** the leading toolbar MUST show an "Edit" button (pencil icon + "Edit" label)

#### Scenario: Close icon in edit mode
- **WHEN** edit mode IS active
- **THEN** the leading toolbar MUST show only an "✕" icon (`xmark.circle.fill`) that, when tapped, exits edit mode and clears the selection set

#### Scenario: Exit edit mode via close
- **WHEN** the user taps the "✕" close button
- **THEN** `isEditMode` MUST be set to `false`
- **AND** `selectedIDs` MUST be cleared
- **AND** the card leading padding MUST animate back to zero and checkboxes MUST disappear

### Requirement: Edit mode does not show inline delete/done in toolbar
The current inline "Delete" and "Done" buttons in the leading toolbar during edit mode SHALL be removed in favor of the floating delete FAB and close icon.

#### Scenario: No inline toolbar buttons during edit mode
- **WHEN** edit mode is active
- **THEN** the leading toolbar area MUST show only the "✕" close icon, NOT the current "Delete" + "Done" HStack
