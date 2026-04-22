## Why
The prior manual split navigation implementation used custom combinations of `.ultraThinMaterial`, `HStack`s, and `safeAreaInset`s, which fall short of the true native iOS 26 Liquid Glass paradigm. To look and feel perfectly at home on iOS 26 / iPadOS 26, the application must abandon these manual recreations and rely entirely on the system's native `TabView`, `GlassEffectView`, and `.tabViewStyle(.sidebarAdaptable)`.

## What Changes
- Destroy previous custom implementations of `FloatingBottomNavBar`, `NavBarTab`, and accompanying layout overlays.
- Strip any usage of `UIBlurEffect` or legacy `.ultraThinMaterial` on tab containers.
- **BREAKING**: Re-architect the primary `DownloadListView` to operate within a true native `TabView`, assigning the explicit iOS 26 `GlassEffect()` background mechanism to achieve authentic refraction.
- Relinquish all active-tab highlight logic (color changes, manual pills) to the system APIs via `.symbolVariants(.fill)`.
- Revert custom `padding` and `safeArea` handling, deferring to the internal GlassEffect mechanics, securing correct layout alignment above the home indicator using `.contentMargins`.

## Capabilities
### New Capabilities
<!-- None -->

### Modified Capabilities
- `download-ui`: Revamp the core layout overlay requirement to strictly prohibit custom floating segment bars in favor of a native `TabView`.
- `liquid-tab-bar`: Enforce true iOS 26 Material (`glassEffect`) APIs over manual blurs and fills.

## Impact
- Extensive refactoring in `DownloadListView.swift` to drop `HStack` bottom overlays and wrap views appropriately in the new context.
- Deletion of manual animation behaviors and state-tracking pill highlights located in `NavigationComponents.swift`.
