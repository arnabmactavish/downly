## 1. Refactor Trailing Toolbar Placement

- [x] 1.1 In `DownloadListView.swift`, locate the `ToolbarItem(placement: .topBarTrailing)` block wrapping an `HStack`.
- [x] 1.2 Change `ToolbarItem` to `ToolbarItemGroup(placement: .topBarTrailing)`.
- [x] 1.3 Remove the `HStack` layout wrapper and keep the two `Button` views (Settings and Add) as direct children of the `ToolbarItemGroup`.

## 2. Apply Native Liquid Glass Modifiers

- [x] 2.1 In `DownloadListView.swift`, append `.toolbarBackground(.ultraThinMaterial, for: .navigationBar)` directly after the `.toolbar { ... }` closing brace.
- [x] 2.2 Append `.toolbarBackground(.visible, for: .navigationBar)` next to it to ensure the liquid glass is always visible, even when the user hasn't scrolled.
