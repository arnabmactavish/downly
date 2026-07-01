## Requirements

### Requirement: Two-finger pan activates selection mode
The download list SHALL support a two-finger vertical pan gesture that activates selection mode and selects cards as fingers move over them, matching Apple's native list multi-select behavior.

#### Scenario: Two-finger pan begins
- **WHEN** user places two fingers on the download list and begins panning vertically
- **THEN** the list SHALL enter selection mode, the first card under the touch point SHALL be selected, and a selection count toolbar SHALL appear

#### Scenario: Panning over additional cards
- **WHEN** user continues panning with two fingers over additional cards
- **THEN** each card the gesture passes over SHALL be toggled into the selected state with a checkmark animation

#### Scenario: Two-finger pan ends
- **WHEN** user lifts both fingers
- **THEN** selection mode SHALL remain active with all selected cards highlighted and a floating action bar showing batch actions (Delete, Pause All, Resume All)

#### Scenario: Deselecting via second two-finger pan
- **WHEN** user performs a second two-finger pan over already-selected cards
- **THEN** those cards SHALL be deselected (toggle behavior)

### Requirement: Selection mode UI
When selection mode is active, the UI SHALL provide visual feedback and batch action controls.

#### Scenario: Selected card appearance
- **WHEN** a card is selected
- **THEN** it SHALL display a leading checkmark circle (filled accent color) and a subtle highlight border

#### Scenario: Selection count display
- **WHEN** one or more cards are selected
- **THEN** a floating toolbar SHALL display "\(count) selected" with "Select All" and "Done" buttons

#### Scenario: Done exits selection mode
- **WHEN** user taps "Done" in the selection toolbar
- **THEN** all selections SHALL be cleared and the UI SHALL return to normal mode

#### Scenario: Integration with existing edit mode
- **WHEN** two-finger selection activates
- **THEN** it SHALL set the same `isEditing` state used by the existing Edit button, ensuring consistent behavior between both entry points
