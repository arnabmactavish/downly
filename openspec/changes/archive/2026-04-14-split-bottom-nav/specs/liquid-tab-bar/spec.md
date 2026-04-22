## MODIFIED Requirements

### Requirement: Liquid Glass Bottom Tab Bar
The application SHALL implement a bottom navigation layout that features an Apple liquid glass appearance, split between a pill-shaped navigation segment and a separate Settings button.

#### Scenario: Visual presentation
- **WHEN** the bottom navigation is rendered
- **THEN** it SHALL use `.ultraThinMaterial` (or equivalent) to create a frosted glass blur on its elements, without any opaque or dark background color filling the entire width

#### Scenario: Settings tab placement
- **WHEN** the bottom navigation UI is displayed
- **THEN** the "Settings" button MUST be positioned as a distinct, standalone circular or capsule-shaped button decoupled from the main tab pill on the trailing edge

#### Scenario: Scrolling content beneath tab
- **WHEN** the user scrolls content in the main view
- **THEN** the scrolled content SHALL pass behind the floating pill and circular button surfaces visibly due to the blur effect, without being blocked by a solid full-width background
