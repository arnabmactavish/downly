## Why

After evaluating the new liquid glass tab bar, it became apparent that combining download status filters and the Settings button into a single full-width bar reduces visual distinction. Splitting the design into two separate floating "liquid glass" elements—a pill-shaped tab bar for status filters and an independent circular button for settings—makes the navigation structure clearer. This closely matches modern iOS "floating segmented" control paradigms, cleanly distinguishing core navigation from secondary settings.

## What Changes

- Modify the unified liquid glass bottom navigation bar into a split design.
- Extract the Settings tab from the main `FloatingBottomNavBar`.
- Render the main navigation filter bar as a floating, pill-shaped `ultraThinMaterial` segment on the leading/center side.
- Render the Settings button as an independent, floating circular button on the trailing side, with a similar `ultraThinMaterial` background.
- Ensure both floating elements are horizontally aligned at the bottom of the screen.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `liquid-tab-bar`: Update the capability to reflect a split layout separating the main navigation tabs from the standalone Settings floating button.

## Impact

- `DownloadListView` layout overlays will group the bottom navigation tabs and the settings button in an `HStack`.
- `FloatingBottomNavBar` will be reverted to or updated to have a capsule/pill shape instead of a full-width background, excluding the settings tab.
