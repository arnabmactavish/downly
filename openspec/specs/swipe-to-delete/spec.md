## Requirements

### Requirement: Left swipe reveals delete action
Each download card SHALL support a left swipe gesture that reveals a destructive delete action.

#### Scenario: Swipe to reveal delete
- **WHEN** user swipes left on a download card
- **THEN** a red trash/delete button SHALL be revealed on the trailing edge of the card

#### Scenario: Tap delete button
- **WHEN** user taps the revealed delete button
- **THEN** a confirmation alert SHALL present asking "Delete this download?" with "Delete" (destructive) and "Cancel" options

#### Scenario: Confirm delete
- **WHEN** user confirms deletion
- **THEN** the download SHALL be cancelled (if active), all temp files cleaned up, the SwiftData record deleted, and the card removed with an animation

#### Scenario: Cancel delete
- **WHEN** user taps "Cancel" on the deletion confirmation
- **THEN** the swipe action SHALL dismiss and the download SHALL remain unchanged

#### Scenario: Full swipe to delete
- **WHEN** user performs a full swipe (swipes all the way to the left)
- **THEN** the deletion confirmation SHALL trigger immediately without requiring a button tap

#### Scenario: Swipe on completed download
- **WHEN** user swipes left on a `.completed` download
- **THEN** the delete action SHALL remove the download record but SHALL NOT delete the completed file from the filesystem
