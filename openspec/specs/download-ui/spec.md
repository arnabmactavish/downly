## ADDED Requirements

### Requirement: Bottom floating navigation bar
The app's main screen SHALL display a floating, pill-shaped navigation bar anchored to the bottom of the screen with five tabs: All, Downloading, Paused, Done, Error.

#### Scenario: Tab filtering
- **WHEN** the user taps a navigation tab
- **THEN** the download list MUST filter to show only items matching that status (All = no filter)

#### Scenario: Floating style
- **WHEN** the navigation bar is rendered
- **THEN** it MUST appear as a rounded-rectangle floating above the scroll content with a Liquid Glass blur background and no system tab bar chrome

#### Scenario: Badge counts
- **WHEN** any tab has items
- **THEN** the tab label MUST show a numeric badge (e.g., "Downloading 2") indicating the item count

### Requirement: Top floating controls
The app SHALL display two floating oval buttons at the top of the screen: Edit (top-left) and Settings (top-right).

#### Scenario: Edit mode
- **WHEN** the user taps the Edit button
- **THEN** the download list enters edit mode, revealing swipe-to-delete and multi-select controls

#### Scenario: Settings navigation
- **WHEN** the user taps the Settings button
- **THEN** a Settings screen SHALL be presented modally

### Requirement: Add download FAB
The main screen SHALL display a prominent floating action button (FAB) for adding a new download.

#### Scenario: FAB placement
- **WHEN** the main screen is displayed
- **THEN** the FAB SHALL appear above the bottom navigation bar, visually distinct (e.g., filled accent color with a `+` icon)

#### Scenario: FAB tap opens modal
- **WHEN** the user taps the FAB
- **THEN** an "Add Download" modal/sheet SHALL present

### Requirement: Add Download modal
The Add Download modal SHALL allow the user to enter a URL, optionally edit the suggested file name, and either start the download or cancel.

#### Scenario: URL input
- **WHEN** the modal opens
- **THEN** a text field pre-populated from the clipboard (if clipboard contains a URL) SHALL be focused

#### Scenario: File name suggestion
- **WHEN** a valid URL is entered
- **THEN** the system SHALL derive a suggested file name from the URL's last path component and populate the file name field

#### Scenario: Start download
- **WHEN** the user taps "Start Download" with a non-empty URL
- **THEN** the modal SHALL dismiss and the download SHALL be added to the queue

#### Scenario: Cancel
- **WHEN** the user taps "Cancel" or swipes down
- **THEN** the modal SHALL dismiss without creating a download

### Requirement: Download item card
Each download in the list SHALL be displayed as a card showing: file name, total size, downloaded size, remaining size, progress percentage, current speed, and a status indicator.

#### Scenario: Downloading state card
- **WHEN** a download is in `.running` state
- **THEN** the card MUST show an animated progress bar, live-updating speed (e.g., "4.2 MB/s"), and estimated time remaining

#### Scenario: Paused state card
- **WHEN** a download is in `.paused` state
- **THEN** the card MUST display a dimmed appearance with a "Paused" label and a resume button

#### Scenario: Completed state card
- **WHEN** a download is in `.completed` state
- **THEN** the card MUST display a green checkmark success indicator and the final file size, with no progress bar

#### Scenario: Error state card
- **WHEN** a download is in `.error` state
- **THEN** the card MUST display a red error indicator, a shortened error message, and a "Retry" button

### Requirement: Liquid Glass design system
All primary UI surfaces (navigation bar, FAB, cards, modal background) SHALL implement the Liquid Glass aesthetic: blur effect background, semi-transparent fills, rounded corners (≥ 20 pt radius for containers), and smooth spring animations.

#### Scenario: Blur background rendering
- **WHEN** any primary surface is rendered over content
- **THEN** it MUST use `UIVisualEffectView` with `.systemUltraThinMaterial` or equivalent SwiftUI `.ultraThinMaterial` for the background blur

#### Scenario: Spring animation on state change
- **WHEN** a download card transitions between states (e.g., running → paused)
- **THEN** the visual change MUST be animated using a spring animation with damping

### Requirement: Real-time UI updates via SwiftData query
The download list SHALL update automatically using SwiftData's `@Query` property wrapper without requiring explicit refresh calls.

#### Scenario: Auto-refresh on model change
- **WHEN** a `DownloadItem`'s status or progress is written to SwiftData
- **THEN** the SwiftUI view observing the `@Query` MUST automatically re-render without any manual `objectWillChange` emission


## Updates from fix-download-bug-and-ui

## ADDED Requirements


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

### Requirement: Top background styling
The top section and header area of the application SHALL NOT utilize a dark background.

#### Scenario: Light/Standard header appearance
- **WHEN** the top navigation area or header is displayed
- **THEN** it SHALL maintain a clean appearance devoid of hardcoded dark backgrounds or restrictive opaque styling, adhering directly to system light/dark modes organically.

## Updates from ios26-liquid-tabbar

## MODIFIED Requirements

### Requirement: FloatingBottomNavBar deprecated
The `<HStack>` overlay implementation representing `FloatingBottomNavBar` SHALL be removed. Instead, the application SHALL adopt a native structural paradigm containing the same navigation elements mapped against a real native container capable of manifesting genuine iOS 26 Material properties.

#### Scenario: Native Layout Execution
- **WHEN** the structural layout container for the download context initializes
- **THEN** it SHALL NOT define a hardcoded `HStack` inside `.safeAreaInset(edge: .bottom)` to act as a false tab-bar placeholder
- **AND** it SHALL leverage native navigation structures configured cleanly with proper `.contentMargins` designed to support true material bleed-through properties underneath


<!-- DELTA SPEC APPENDED DUE TO SYNC FAILURE -->

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
