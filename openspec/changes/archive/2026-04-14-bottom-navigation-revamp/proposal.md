# Proposal: Bottom Navigation Revamp

## 1. Problem Statement
The current application utilizes a custom floating bottom navigation bar embedded within the `DownloadListView` overlay. Concurrently, the Settings screen is presented as a modal sheet disjointed from the core navigation hierarchy. This structure deviates from standard iOS paradigms, creating a somewhat fragmented user experience.

## 2. Proposed Solution
Implement a total revamp of the bottom navigation by transitioning to a native SwiftUI `TabView`. The `TabView` will handle the primary routing between the Download sections and the Settings screen. Instead of opening Settings as a modal sheet, it will exist as a dedicated tab, creating a coherent, flat navigation hierarchy. The design will maintain the Liquid Glass aesthetic native to iOS, ensuring visual consistency and a premium feel.

## 3. Scope
- Main App entry point will utilize `TabView`.
- `DownloadListView` will be one tab (e.g., "Downloads" with its own internal state/filters).
- `SettingsView` will be the second tab (e.g., "Settings"), no longer a modal sheet.
- The `FloatingBottomNavBar` and `SettingsCircularButton` will be deprecated in favor of a native, Liquid Glass `TabView`.

## 4. Non-Goals
- Altering the SwiftData persistence layer.
- Changing the existing Add Download logic or `+` button in the navigation bar.
