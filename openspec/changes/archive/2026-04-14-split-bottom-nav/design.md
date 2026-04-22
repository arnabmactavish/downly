## Context
Following the recent integration of the liquid glass bottom tab bar, it was observed that combining the primary download navigation (status filters) with the Settings action into a single full-width bar decreases visual hierarchy. Comparing this to native iOS patterns, splitting these into a discrete pill-shaped navigation segment and an independent Settings circular button offers a more elegant and scannable interface.

## Goals / Non-Goals
**Goals:**
- Separate the "Settings" button from the bottom filter tabs.
- Re-shape the bottom filter tabs into a floating, pill-shaped "liquid glass" `.ultraThinMaterial` view that pads out from the horizontal edges.
- Create a distinct circular or rounded square floating liquid glass button for Settings, positioned to the trailing edge.

**Non-Goals:**
- Removing the liquid glass aesthetic.
- Moving the "Add" button from the top right.

## Decisions
- **HStack Layout Strategy**: We will utilize an `HStack` inside the existing `.safeAreaInset(edge: .bottom)` wrapper surrounding the `ScrollView`. This `HStack` will contain the `FloatingBottomNavBar` pill on the leading/center side, a `Spacer()`, and a `FloatingOvalButton` or similar circular button for the Settings on the trailing side.
- **FloatingBottomNavBar Reversion**: `FloatingBottomNavBar` will be updated to restore its `.liquidGlass(cornerRadius: DS.Radius.pill)` modifier and will drop the integrated Settings button layout.

## Risks / Trade-offs
- **[Risk] Safe Areas**: Floating segmented controls must not overlap the home indicator. 
  - *Mitigation*: We will apply bottom padding to the `HStack` to push the pill and circle off the very bottom of the screen.
