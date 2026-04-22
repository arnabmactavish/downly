## REMOVED Requirements

### Requirement: Settings button in navigation bar
**Reason**: Settings button is being moved to the bottom tab bar.
**Migration**: Use the "Settings" tab in the new liquid bottom tab bar.

## MODIFIED Requirements

### Requirement: Add (+) button in top-right navigation bar
The Add download action SHALL be represented by a `+` icon (`"plus"`) `Button` placed in the `.topBarTrailing` toolbar position. It MUST be the exclusive button in the top right, to eliminate clutter.

#### Scenario: Add button visible in nav bar
- **WHEN** `DownloadListView` is displayed
- **THEN** a `+` icon button SHALL appear in the trailing navigation bar area by itself without the Settings button next to it

#### Scenario: Add button has no extra background
- **WHEN** the `+` icon button is rendered
- **THEN** it SHALL NOT display any material blur, fill, or dark background

#### Scenario: Add button opens add-download sheet
- **WHEN** the `+` icon button is tapped
- **THEN** `AddDownloadSheet` SHALL be presented as a sheet

## ADDED Requirements

### Requirement: Top background styling
The top section and header area of the application SHALL NOT utilize a dark background.

#### Scenario: Light/Standard header appearance
- **WHEN** the top navigation area or header is displayed
- **THEN** it SHALL maintain a clean appearance devoid of hardcoded dark backgrounds or restrictive opaque styling, adhering directly to system light/dark modes organically.
