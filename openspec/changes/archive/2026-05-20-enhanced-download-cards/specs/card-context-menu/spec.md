## ADDED Requirements

### Requirement: Long press context menu on download cards
Each download card SHALL display a context menu on long press with actions appropriate to the download's current state.

#### Scenario: Running download context menu
- **WHEN** user long presses a download in `.running` state
- **THEN** the context menu SHALL show: Pause, Cancel, Copy URL, Share

#### Scenario: Paused download context menu
- **WHEN** user long presses a download in `.paused` state
- **THEN** the context menu SHALL show: Resume, Update URL, Cancel, Copy URL, Share

#### Scenario: Error download context menu
- **WHEN** user long presses a download in `.error` state
- **THEN** the context menu SHALL show: Retry, Update URL, Copy URL, Copy Error, Delete

#### Scenario: Completed download context menu
- **WHEN** user long presses a download in `.completed` state
- **THEN** the context menu SHALL show: Open File, Share File, Copy URL, Delete Record

#### Scenario: Pending download context menu
- **WHEN** user long presses a download in `.pending` state
- **THEN** the context menu SHALL show: Cancel, Copy URL

### Requirement: Context menu actions execute correctly
Each context menu action SHALL perform its intended operation.

#### Scenario: Copy URL action
- **WHEN** user selects "Copy URL" from context menu
- **THEN** the download's URL SHALL be copied to system clipboard and a brief toast/haptic SHALL confirm the action

#### Scenario: Share action
- **WHEN** user selects "Share" from context menu on a running/paused download
- **THEN** a `UIActivityViewController` SHALL present with the download URL

#### Scenario: Share File action
- **WHEN** user selects "Share File" from context menu on a completed download
- **THEN** a `UIActivityViewController` SHALL present with the completed file

#### Scenario: Update URL action
- **WHEN** user selects "Update URL" from context menu
- **THEN** the URL update sheet SHALL present (as defined in `url-update-resume` spec)

#### Scenario: Delete Record action on completed download
- **WHEN** user selects "Delete Record" from context menu on a completed download
- **THEN** the SwiftData record SHALL be deleted but the downloaded file SHALL be preserved in the filesystem

### Requirement: Context menu preview
The context menu SHALL display a preview of the download card during the long press interaction.

#### Scenario: Preview appearance
- **WHEN** user long presses and the context menu appears
- **THEN** the card SHALL lift with a scaled preview matching system context menu behavior using `.contentShape` and the native `.contextMenu(menuItems:preview:)` API
