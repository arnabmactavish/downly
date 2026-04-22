## ADDED Requirements

### Requirement: Liquid Glass Bottom Tab Bar
The application SHALL implement a bottom navigation tab bar that features an Apple liquid glass appearance.

#### Scenario: Visual presentation
- **WHEN** the bottom tab bar is rendered
- **THEN** it SHALL use `.ultraThinMaterial` (or equivalent) to create a frosted glass blur effect without any opaque or dark background color

#### Scenario: Settings tab placement
- **WHEN** the tab bar items are displayed
- **THEN** the "Settings" button MUST be positioned as the absolute last (trailing-most) item or section on the tab bar

#### Scenario: Scrolling content beneath tab
- **WHEN** the user scrolls content in the main view
- **THEN** the scrolled content SHALL pass behind the tab bar surface visibly due to the blur effect, without being blocked by a solid background
