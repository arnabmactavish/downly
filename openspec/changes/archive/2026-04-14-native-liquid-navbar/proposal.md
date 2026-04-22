## Why

The user reported that the current navigation bar is not rendering with Apple's native iOS liquid design (frosted glass blur), and the Settings button placement needs native integration into the navigation bar. SwiftUI can sometimes strip or mask native toolbar features when using custom `HStack`s inside a single `ToolbarItem`, or when the background colour/ignoresSafeArea modifiers interfere with the system's scroll edge appearance. 

## What Changes

- **ToolbarItemGroup for Trailing Buttons**: Refactor the trailing navigation bar buttons (Settings, Add) from a custom `HStack` inside a single `ToolbarItem` into a native layout using `ToolbarItemGroup` to ensure native hit-states, spacing, and iOS rendering.
- **Native Liquid Glass Navbar**: Apply `.toolbarBackground(.visible, for: .navigationBar)` and `.toolbarBackground(.ultraThinMaterial, for: .navigationBar)` to enforce Apple's native liquid glass navbar aesthetic, preventing it from appearing incorrectly due to the full-screen ZStack background.

## Capabilities

### Modified Capabilities

- `download-ui`: Refined native navigation bar rendering and toolbar item grouping.

## Impact

- **`Downly/UI/Screens/DownloadListView.swift`**: Update `.toolbar` block to use `ToolbarItemGroup` and add `.toolbarBackground` modifiers to enforce the native liquid glass design.
