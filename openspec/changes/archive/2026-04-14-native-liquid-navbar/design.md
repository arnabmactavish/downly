## Context

The user noticed that the navigation bar (at the top of the screen) lacked the native "liquid design" (Apple's `ultraThinMaterial` frosted glass effect). Furthermore, the Settings and Add buttons were previously placed inside an `HStack` within a single `ToolbarItem`. SwiftUI's `NavigationBar` prefers distinct `ToolbarItem` instances or a `ToolbarItemGroup` to apply system-level tinting, spacing, and accessibility behaviors perfectly.

## Goals

- **Native Look**: Force the top navigation bar to render using Apple's native liquid design (frosted glass) at all times, independent of scroll position interference.
- **Proper Toolbars**: Separate multiple trailing buttons into a standard grouped layout so iOS handles their placement correctly.

## Decisions

### Decision 1: Use `.toolbarBackground` Modifiers
**Chosen**: We will add the following to `DownloadListView`'s main container:
```swift
.toolbarBackground(.visible, for: .navigationBar)
.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
```
**Rationale**: In iOS 16+, these modifiers explicitly tell the system navigation bar to ignore standard scroll-edge assumptions and strictly use a frosted glass material.

### Decision 2: Use `ToolbarItemGroup`
**Chosen**: Replace the trailing `ToolbarItem` holding the `HStack` with a `ToolbarItemGroup(placement: .topBarTrailing)`.
**Rationale**: Distinctly declaring Buttons inside a `ToolbarItemGroup` ensures that Apple's layout engine can size, offset, and hit-test the gear and plus icons using native iOS conventions.

## Risks / Trade-offs

- The `toolbarBackground` might conflict if there are complex transitions to detail screens, but Downly currently relies primarily on sheets (Add/Settings) which overlap perfectly.
