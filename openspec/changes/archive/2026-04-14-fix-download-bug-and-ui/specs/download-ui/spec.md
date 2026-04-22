## ADDED Requirements

### Requirement: Settings button in navigation bar
The Settings button SHALL be placed as an icon-only `Button` (gear icon `"gearshape"`) in the `.topBarTrailing` toolbar position of `DownloadListView`, without any liquid-glass background material.

#### Scenario: Settings button visible in nav bar
- **WHEN** `DownloadListView` is displayed
- **THEN** a gear icon button SHALL appear in the trailing navigation bar area

#### Scenario: Settings button has no extra background
- **WHEN** the gear icon button is rendered
- **THEN** it SHALL NOT display any material blur, fill, or border background — only the icon itself

#### Scenario: Settings button opens Settings sheet
- **WHEN** the gear icon button is tapped
- **THEN** `SettingsView` SHALL be presented as a sheet

### Requirement: Add (+) button in top-right navigation bar
The Add download action SHALL be represented by a `+` icon (`"plus"`) `Button` placed in the `.topBarTrailing` toolbar position, to the right of the Settings/Edit button, without any liquid-glass background.

#### Scenario: Add button visible in nav bar
- **WHEN** `DownloadListView` is displayed
- **THEN** a `+` icon button SHALL appear in the trailing navigation bar area

#### Scenario: Add button has no extra background
- **WHEN** the `+` icon button is rendered
- **THEN** it SHALL NOT display any material blur, fill, or border background

#### Scenario: Add button opens add-download sheet
- **WHEN** the `+` icon button is tapped
- **THEN** `AddDownloadSheet` SHALL be presented as a sheet

### Requirement: AddDownloadFAB removed from bottom overlay
The circular floating action button (`AddDownloadFAB`) SHALL be removed from the bottom `VStack` overlay in `DownloadListView`. The bottom area SHALL contain only `FloatingBottomNavBar`.

#### Scenario: Bottom area shows only the filter nav bar
- **WHEN** `DownloadListView` is displayed
- **THEN** the bottom overlay SHALL contain only the `FloatingBottomNavBar` filter tabs, with no FAB circle above it

### Requirement: Toolbar buttons rendered without background material
`FloatingOvalButton` and any button used in the navigation toolbar SHALL NOT apply `.liquidGlass(...)` or any custom background when placed as a toolbar item.

#### Scenario: Edit button has no background
- **WHEN** the Edit / pencil button is shown in the leading toolbar position
- **THEN** it SHALL render as an icon+label without liquid-glass material

#### Scenario: FloatingBottomNavBar uses clean glass
- **WHEN** `FloatingBottomNavBar` is rendered
- **THEN** its background SHALL use `.ultraThinMaterial` only — no additional `glassFill` colour overlay — producing a neutral glass appearance without a tinted background colour
