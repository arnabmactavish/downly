## 1. FloatingBottomNavBar Update

- [x] 1.1 Remove the structural Settings button `VStack` integration from `FloatingBottomNavBar` inside `NavigationComponents.swift`.
- [x] 1.2 Revert `FloatingBottomNavBar` styling back to use `liquidGlass(cornerRadius: DS.Radius.pill)` instead of full-width background styling.
- [x] 1.3 Ensure `FloatingBottomNavBar` only iterates over `DownloadFilter.allCases` for navigation items.

## 2. Separate Settings Button Implementation

- [x] 2.1 In `DownloadListView.swift`, replace the single bottom bar call with an `HStack` that separates the navigation pill and the settings button.
- [x] 2.2 Create a circular Settings button (`Button`) on the trailing side of the `HStack` using `.liquidGlass(cornerRadius: DS.Radius.pill)` to match the native split overlay style.

## 3. Layout Adjustments

- [x] 3.1 Keep the new split bottom navigation `HStack` inside the `.safeAreaInset(edge: .bottom)` wrapper so the main `ScrollView` automatically pads the list content.
- [x] 3.2 Apply appropriate `.padding(.horizontal)` and `.padding(.bottom)` to the `HStack` so the split elements hover distinctively above the bottom edge of the screen.
