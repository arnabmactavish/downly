## Why

Downloads silently fail because `URLSessionDownloadTask` temp files are deleted by the system before `DownloadQueueManager` can move them — a race condition in the notification-based handoff. Alongside this, the top toolbar buttons carry an unwanted liquid-glass background material, the navbar needs to be a clean system glass style, the Settings button should live in the nav bar, and the Add (+) button should move to the top-right corner.

## What Changes

- **Fix download race condition**: Copy the temp file to a stable location inside the `DownloadEngine.handleCompletion` callback (while the file is still valid), then post the notification with the stable path — eliminating the race between `URLSessionDownloadTask` and `DownloadQueueManager.waitForSingleStreamCompletion`.
- **Remove toolbar button backgrounds**: `FloatingOvalButton` (Edit, Settings) currently wraps its content in `.liquidGlass(...)`, adding an unintended background material behind toolbar items. Strip the background from toolbar-context buttons.
- **Liquid glass navbar**: The `FloatingBottomNavBar` should use a clean `.ultraThinMaterial` glass without additional `DS.Colors.glassFill` overlay tint that produces a coloured background.
- **Move Settings to nav bar**: Remove the `FloatingOvalButton("Settings")` from the trailing toolbar. Replace with an icon-only `Button` placed in the `.topBarTrailing` toolbar slot that presents `SettingsView`.
- **Add (+) to top-right corner**: Remove `AddDownloadFAB` from the floating bottom `VStack`. Add a `+` icon `Button` in the `.topBarTrailing` toolbar (alongside or in place of the old Settings button position), keeping the bottom nav bar clean.

## Capabilities

### New Capabilities

- `download-engine-file-handoff`: Safe temp-file preservation in `DownloadEngine` before notification posting.

### Modified Capabilities

- `download-ui`: Toolbar layout changes — Settings icon to navbar, Add (+) to top-right, remove button background materials.

## Impact

- **`Downly/Engine/DownloadEngine.swift`** — `handleCompletion`: copy temp file to a stable URL before posting `.downloadTaskDidFinish`.
- **`Downly/Queue/DownloadQueueManager.swift`** — `waitForSingleStreamCompletion`: consume the stable URL instead of `tempLocation`.
- **`Downly/UI/Components/NavigationComponents.swift`** — `FloatingOvalButton`: make background opt-in; update `FloatingBottomNavBar` glass style.
- **`Downly/UI/Screens/DownloadListView.swift`** — toolbar restructure: Settings icon + Add `+` button in top-right; remove `AddDownloadFAB` from bottom.
