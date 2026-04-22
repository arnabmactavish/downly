## Context

The current `DownloadListView` has a heavily populated top navigation bar area. The previous change added Settings and Add buttons to the top right with transparent backgrounds, but they are still clustered together. Furthermore, the bottom floating bar is currently only used for download filtering. To provide a modern, premium natively-feeling interface, we need to eliminate any dark backgrounds from the top section, isolate the "Add" button in the top right, and introduce an Apple "liquid glass" style bottom navigation tab bar that incorporates "Settings" as its final section.

## Goals / Non-Goals

**Goals:**
- Implement a liquid glass effect utilizing Apple's thin materials for a unified bottom navigation tab bar.
- Move the "Settings" button to the bottom tab bar as the final (trailing) section.
- Simplify the top-right toolbar to exclusively feature the "Add" (+ ) button.
- Ensure the top navigation area is clear of intrusive dark backgrounds.

**Non-Goals:**
- Rewriting the entire application architecture to depend purely on Apple's default `TabView`, if a custom layout overlay best serves the Liquid Glass requirement and existing filter tabs.
- Altering the core downloader logic.

## Decisions

- **Replacing FloatingBottomNavBar with a Unified App Tab Bar**: The current `FloatingBottomNavBar` only filters the download list. We will evolve it into a robust bottom tab bar (using `.ultraThinMaterial`). The final tab item will be "Settings", maintaining the existing filter selections either as parallel tabs or within a main "Downloads" tab. 
- **Top Navigation Bar Styling**: We'll explicitly strip dark background modifiers (or force a specific color scheme if `.dark` is overriding top elements) for `DownloadListView`'s navigation bar, leaning on standard light/dark mode adaptations and hiding any hardcoded dark headers.

## Risks / Trade-offs

- **[Risk] Clutter in Bottom Bar**: Combining download state filters (All, Downloading, Paused, etc.) and global sections (Settings) might create overcrowding.
  - *Mitigation*: We may compress the download filter into a primary "Downloads" tab that reveals sub-filters, or simply append Settings if screen real estate allows.
- **[Risk] Incorrect Material Rendering**: A true liquid glass effect needs the content to scroll beneath the bar. 
  - *Mitigation*: The custom tab bar must remain an overlay above the primary `ScrollView` or `List`, ignoring bottom safe areas for its background, but applying appropriate bottom padding to the content.
