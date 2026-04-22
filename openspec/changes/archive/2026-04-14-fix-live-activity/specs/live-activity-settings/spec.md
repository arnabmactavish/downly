## ADDED Requirements

### Requirement: Live Activity user preference toggle
The system SHALL expose a toggle in Settings that allows users to enable or disable Live Activities for downloads.

#### Scenario: Toggle is visible in Settings
- **WHEN** the user opens the Settings screen
- **THEN** a "Live Activities" toggle MUST be displayed within a dedicated card section

#### Scenario: Toggle defaults to enabled
- **WHEN** a user has never changed the Live Activity setting
- **THEN** the toggle MUST default to `true` (Live Activities enabled)

#### Scenario: Toggle persists across launches
- **WHEN** the user sets the toggle to `false` and relaunches the app
- **THEN** the setting MUST remain `false`

#### Scenario: Tradeoff note is shown
- **WHEN** the toggle is rendered
- **THEN** secondary caption text MUST be shown explaining: (a) what Live Activities provide and (b) the potential battery impact during large downloads

#### Scenario: Disabled preference is respected at start time
- **WHEN** `liveActivitiesEnabled` is `false` in UserDefaults
- **THEN** `LiveActivityManager.startActivity(for:)` MUST return without calling `Activity.request`, so no Live Activity is created for new downloads
