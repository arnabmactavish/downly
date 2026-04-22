# Design: Bottom Navigation Revamp

## 1. Overview
The architecture will shift from a single `DownloadListView` containing custom overlays to an `App` level `TabView`. This aligns the app with standard, multi-pane iOS applications.

## 2. TabView Structure
- **Tab 1: Downloads**
  - View: `DownloadListView` wrapped in a `NavigationStack`.
  - Icon: `arrow.down.circle.fill`
  - Functionality: Retains the list of downloads, the top bar `+` (Add Download) and Edit functions. It may need internal filtering if the previous bottom tabs (All, Downloading, etc.) are moved. Wait, if the main TabView only has 2 tabs (Downloads, Settings), how do we handle the download status filters (All, Downloading, Paused, etc.)? We can migrate the filters to a top segmented control or an internal top header, or keep them as a sub-navigation bar. Given "Total revamp of bottom navigation", the previous status filters might need to be relocated. We'll use a standard Picker/SegmentedControl at the top for filtering statuses.

- **Tab 2: Settings**
  - View: `SettingsView` wrapped in a `NavigationStack` (if not already).
  - Icon: `gearshape.fill`

## 3. UI/UX Changes
- **Liquid Glass Theme:** The `TabView` will utilize `.toolbarBackground(.visible, for: .tabBar)` and `.toolbarBackground(.ultraThinMaterial, for: .tabBar)` to ensure the true iOS Liquid Glass design is applied.
- **Filter Relocation:** Migrate `DownloadFilter` from bottom tabs to a top-level `Picker` (Segmented Style) placed either in the toolbar or just below the navigation bar inside `DownloadListView`.
- **Remove Modal:** Remove the `.sheet(isPresented: $showSettings)` modifier from `DownloadListView`.

## 4. Dependencies
- Updates to `DownlyApp.swift` or a new `MainTabView.swift`.
- Refactoring `DownloadListView` to remove the custom floating bottom bar.
