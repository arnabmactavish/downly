## Why

The current user interface requires a refresh to improve aesthetics and usability. Specifically, the top section's dark background makes the UI feel heavy, and placing the Settings and Add buttons together creates a cluttered layout. A refined bottom navigation bar using Apple's liquid glass styling (materials) will offer a premium native look, and moving the Settings button into this bottom bar will improve logical grouping.

## What Changes

- Remove the dark background from the top section to create a cleaner, native feel.
- Relocate the Settings button away from the top-right corner.
- Ensure only the Add button remains in the top-right corner.
- Implement a bottom navigation tab bar using an elegant Apple "liquid glass" effect.
- Move the Settings navigation item to be the last section in the new bottom tab bar.

## Capabilities

### New Capabilities

- `liquid-tab-bar`: Implement a dynamic, frosted-glass-style bottom tab bar with integrated navigation items including the newly repositioned Settings button.

### Modified Capabilities

- `download-ui`: Update the top navigation bar region to remove the dark background and the settings button, leaving only the add button.

## Impact

- The primary navigation structure will transition from potentially top-heavy toolbars to a standard or custom bottom tab bar.
- `DownloadListView` or subsequent main container views will need structural updates to host either a standard `TabView` with `UITabBarAppearance` or a custom SwiftUI bottom bar with `ultraThinMaterial`.
- Top toolbar configurations across main screens will be simplified.
