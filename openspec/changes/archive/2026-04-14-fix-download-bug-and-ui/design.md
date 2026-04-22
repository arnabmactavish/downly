## Context

Downly uses a layered architecture: `DownloadEngine` (actor, wraps `URLSession`) → `DownloadQueueManager` (`@MainActor` class) → SwiftUI views. Two categories of issues are addressed:

**Download bug**: `URLSessionDownloadDelegate.urlSession(_:downloadTask:didFinishDownloadingTo:)` provides a temporary file at `location` that is **only valid for the duration of that callback**. Apple's documentation states the file is moved or deleted immediately after the delegate method returns. `DownloadEngine.handleCompletion` posts a `NotificationCenter` notification with the raw `URL` from that callback, then returns. By the time `DownloadQueueManager.waitForSingleStreamCompletion` receives the notification and attempts `FileManager.moveItem(at:to:)`, the temp file no longer exists — causing a silent failure.

**UI issues**: `FloatingOvalButton` unconditionally applies `.liquidGlass(cornerRadius:)` which paints an `ultraThinMaterial` blur + fill behind every usage — including toolbar items, where UIKit already renders the navigation bar background. This produces a double-background visual artefact. The FAB+ button and Settings button placement also conflict with the intended iOS 26 Liquid Glass navbar design: Settings should sit in the navigation bar, and Add should appear as a plain icon in the top-right, freeing the bottom area to show only the filter tab bar.

## Goals / Non-Goals

**Goals:**
- Eliminate the temp-file race: stabilise the downloaded file before handing off to `DownloadQueueManager`.
- Remove unintended background material on `FloatingOvalButton` when used in toolbar contexts.
- Refactor toolbar: Settings icon in top-right of navigation bar; `+` Add button also in top-right; remove `AddDownloadFAB` from bottom overlay.
- Ensure `FloatingBottomNavBar` uses clean glass without extra colour tint overlay.

**Non-Goals:**
- Changing the chunked download path (already handled by `ChunkCoordinator` which writes its own stable temp files before calling `onChunkComplete`).
- Redesigning the overall navigation structure.
- Adding new download features.

## Decisions

### Decision 1: Copy temp file inside `handleCompletion` before posting notification

**Chosen**: In `DownloadEngine.handleCompletion`, immediately copy `tempLocation` to a durable path (e.g. `FileManager.default.temporaryDirectory/<downloadID>.tmp`) before posting the notification. The stable URL is included in `userInfo` as `"stableLocation"`. `DownloadQueueManager.waitForSingleStreamCompletion` reads `"stableLocation"` instead of `"tempLocation"`.

**Alternative considered**: Move the `FileManager.moveItem` call into `DownloadEngine` itself. Rejected — `DownloadEngine` should not know about destination file naming or the Documents directory. That responsibility belongs to `DownloadQueueManager`.

**Rationale**: Minimal change surface; preserves the existing notification-based decoupling; the copy is cheap (same volume on-device).

### Decision 2: Make `FloatingOvalButton` background opt-in

**Chosen**: Add a `showBackground: Bool` parameter (default `true`) to `FloatingOvalButton`. Callers in the navigation toolbar pass `showBackground: false`. This preserves existing usage for any floating standalone buttons while fixing toolbar artefacts.

**Alternative**: Create a separate `ToolbarIconButton` component. Rejected as over-engineering for this change.

### Decision 3: Toolbar restructure — plain icon buttons

**Chosen**: Replace toolbar uses of `FloatingOvalButton` with plain SwiftUI `Button` + `Image(systemName:)` for Settings (gear icon) and Add (`+` / `plus` icon). Both go in `.topBarTrailing` — Add on the far right, Settings to its left. The Edit button stays as-is (leading toolbar).

**Rationale**: Native toolbar buttons inherit navigation bar appearance automatically without extra material. Matches iOS HIG for toolbar actions.

### Decision 4: Bottom nav bar glass clean-up

**Chosen**: In `LiquidGlassBackground`, the existing `DS.Colors.glassFill` (`.white.opacity(0.08)`) overlay is the source of the visible tint on the nav bar. Remove this overlay from the `FloatingBottomNavBar` by passing `tint: .clear` and updating `LiquidGlassBackground` to skip the `glassFill` layer when tint is `.clear` (it already conditionally skips the tint overlay, but the `glassFill` base is always applied). Introduce a `showFill: Bool` flag on `liquidGlass(...)` to allow callers to opt out.

## Risks / Trade-offs

- **Stable temp file accumulation** → Mitigation: `DownloadQueueManager.waitForSingleStreamCompletion` deletes the stable copy after a successful move or on error.
- **Disk space for the stable copy** → Mitigation: The stable copy is in `tmp/` and is the same size as the downloaded file; the original temp is deleted by the system immediately. Net disk usage is unchanged.
- **Toolbar button discoverability** → Trade-off: Icon-only buttons (no label) are less discoverable than `FloatingOvalButton` labels. Accepted per the user's explicit UI direction; standard iOS gear + plus icons are universally recognised.
