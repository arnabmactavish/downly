## 1. Update Top Navigation Bar

- [x] 1.1 Remove any dark background styling or liquid glass overlays from the top navigation bar elements in `DownloadListView.swift`.
- [x] 1.2 Remove the Settings gear icon `Button` from the `.topBarTrailing` toolbar position.
- [x] 1.3 Ensure the Add (`+`) `Button` remains as the sole element in the `.topBarTrailing` toolbar position and has a clean, natural background.

## 2. Implement Liquid Tab Bar

- [x] 2.1 Refactor/adapt the bottom view overlay in `DownloadListView.swift` to serve as a comprehensive Liquid Glass bottom tab bar.
- [x] 2.2 Apply `.ultraThinMaterial` background to the bottom tab bar to achieve the frosted glass effect without solid backing colors.
- [x] 2.3 Add a new "Settings" button/tab at the end (trailing position) of the existing bottom navigation filter list.

## 3. Wire Navigation and UI Refinement

- [x] 3.1 Connect the new "Settings" tab in the bottom bar to toggle the `showingSettings` state, presenting `SettingsView` as a sheet.
- [x] 3.2 Add appropriate bottom padding to the main `ScrollView` or `List` (e.g., via `.safeAreaInset(edge: .bottom)`) so the last download items aren't completely hidden behind the new bottom bar.
- [x] 3.3 Verify that background content scrolls visibly behind the liquid glass tab bar.
