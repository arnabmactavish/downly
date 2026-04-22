## Why

The Live Activity integration in Downly is architecturally wired but never fires. `LiveActivityManager.startActivity(for:)` is never called at the point a download transitions to `.running`, and the `DownloadProgressCoordinator` that drives updates is created inside `executeDownload` without first calling `startActivity`. As a result, the banner, Lock Screen widget, and Dynamic Island never appear. Additionally, there is no user-facing control to opt out of Live Activities, which is expected in a mature settings screen.

## What Changes

- **Invoke `LiveActivityManager.startActivity` before progress updates begin** — call it inside `DownloadQueueManager.executeDownload` immediately after the item transitions to `.running`, ensuring the Live Activity exists before the first `updateActivity` call.
- **Wire chunked-download path** — the chunked code path currently never calls `startActivity` or updates the Live Activity as `ChunkCoordinator` progresses; add a `DownloadProgressCoordinator` (or equivalent update calls) to feed Live Activity updates for chunk-based downloads too.
- **Live Activity toggle in Settings** — add an `@AppStorage("liveActivitiesEnabled")` toggle in `SettingsView` with a concise tradeoff note (battery/distraction vs. real-time awareness).
- **Respect the user toggle in `LiveActivityManager`** — read `UserDefaults` in `startActivity` and bail early if `liveActivitiesEnabled == false`.
- **Duplicate `DownloadAttributes` declaration** — `DownloadAttributes` and `DownloadStatus` are defined in both the main app target and the widget extension independently. Verify both stay in sync (same fields, same behavior); document in proposal so the design phase explicitly addresses keeping them aligned.
- **Fix `DownloadStatus.running` default fallback in widget** — `ContentState.status` falls back to `.running` on decode failure; validate this is intentional and matches the app target's fallback.

## Capabilities

### New Capabilities
- `live-activity-settings`: In-app toggle to enable/disable Live Activities with user-visible tradeoff explanation.

### Modified Capabilities
- `live-activity`: Requirements now include (a) `startActivity` is called at download start, (b) chunked downloads also receive Live Activity updates, and (c) the user-preference toggle is respected at start time.

## Impact

- **`DownloadQueueManager.swift`** — add `startActivity` calls in `executeDownload` (both single-stream and chunked paths), and feed Live Activity updates during chunk completion.
- **`LiveActivityManager.swift`** — read `UserDefaults["liveActivitiesEnabled"]` before requesting an activity.
- **`SettingsView.swift`** — add a new `liveActivities` card with a `Toggle` and tradeoff footer.
- **`DownloadProgressCoordinator.swift`** — no structural changes needed; coordinator already calls `updateActivity`. Just needs `startActivity` to have been invoked first.
- No new frameworks required; `ActivityKit` is already imported.
