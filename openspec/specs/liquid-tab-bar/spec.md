## ADDED Requirements

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

## Updates from ios26-liquid-tabbar

## MODIFIED Requirements

### Requirement: Liquid Glass Bottom Tab Bar
The application SHALL implement a bottom navigation layout utilizing strictly iOS 26 native `GlassEffectView` or `.glassEffect` system APIs to render the Liquid Glass appearance.

#### Scenario: System Container Setup
- **WHEN** the bottom navigation is functionally rendered
- **THEN** it SHALL leverage native macOS / iOS 26 containers integrating `.glassEffect(_:in:isEnabled:)` with a `ContainerRelativeShape` (or similar iOS 26 API structure) natively
- **AND** it SHALL NOT contain manually appended rendering modifiers such as `.background(.ultraThinMaterial)`, `UIBlurEffect`, or arbitrary background layers that pollute the true hardware-accelerated material

#### Scenario: Native Capsule Indicators
- **WHEN** a navigation tab transitions into an active selection
- **THEN** it SHALL represent its active state exclusively utilizing `.symbolVariants(.fill)` via SF Symbols against the native Label
- **AND** all existing, manually implemented UI background shapes / filled pills designed to act as tab indicator highlights MUST be deleted entirely

#### Scenario: True Layout Bleed
- **WHEN** content populates under the layout space allocated to the navigation bar
- **THEN** the encompassing standard bounds SHALL seamlessly traverse behind the TabBar utilizing proper iOS `.contentMargins` configurations if required (while abstaining from manually shifting offsets upward using structural overlays/paddings exclusively to bypass home indicator overlap considerations)
