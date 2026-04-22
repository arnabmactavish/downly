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
