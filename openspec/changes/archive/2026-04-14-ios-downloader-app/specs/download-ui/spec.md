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
