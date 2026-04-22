## Context

Downly has a fully scaffolded Live Activity layer: `DownloadAttributes`, `LiveActivityManager`, `DownloadProgressCoordinator`, and a widget extension (`DownloadLiveActivityWidget`). However, the Live Activity never fires because `LiveActivityManager.startActivity(for:)` is never invoked when a download begins. `DownloadProgressCoordinator` correctly calls `updateActivity` on every progress tick, but since no activity was started, there is nothing to update. The `DownloadQueueManager` also never calls `startActivity` in either its single-stream or chunked code path.

Secondary gaps:
1. The chunked download path has no Live Activity progress path at all — the `ChunkCoordinator` callback only updates SwiftData, not the Live Activity.
2. `SettingsView` has no user toggle for Live Activities, though `ActivityAuthorizationInfo().areActivitiesEnabled` is already checked in `LiveActivityManager`.
3. `DownloadAttributes` and `DownloadStatus` are duplicated in both the main target (`Downly/LiveActivity/`) and the widget extension (`DownlyWidgetExtension/`). They are currently identical, but changes to one won't automatically propagate to the other.

## Goals / Non-Goals

**Goals:**
- Call `LiveActivityManager.startActivity(for:)` at the correct moment (download transitions to `.running`) in both single-stream and chunked paths.
- Feed Live Activity progress updates through the existing `DownloadProgressCoordinator` for single-stream downloads (already correct — just needs `startActivity` first).
- Approximate Live Activity updates for chunked downloads using per-chunk completion callbacks and a synthesised `DownloadProgress`.
- Add a `liveActivitiesEnabled` toggle to `SettingsView` with a tradeoff note.
- Respect the `liveActivitiesEnabled` preference in `LiveActivityManager.startActivity`.

**Non-Goals:**
- Merging the duplicated `DownloadAttributes`/`DownloadStatus` files into a shared framework — complex Xcode target membership change, tracked as tech debt.
- Push-notification-based Live Activity updates (pushType: nil is correct for local updates).
- Live Activity support for iOS < 16.2 (already guarded).

## Decisions

### D1: Where to call `startActivity`

**Decision:** Call `startActivity` inside `DownloadQueueManager.executeDownload`, immediately after the item is marked `.running` and before any delegate callbacks can fire.

**Rationale:** `DownloadProgressCoordinator.updateActivity` is already being called via the progress stream observed in `observe(stream:downloadID:)`. The only missing piece is the initial `startActivity`. Placing it synchronously before `engine.startDownload` guarantees the activity handle exists before the first `updateActivity` in `LiveActivityManager`'s `activities[id]` dictionary.

**Alternative considered:** Calling from `DownloadQueueManager.addDownload` — rejected because the item hasn't confirmed server reachability yet (HEAD request happens inside `executeDownload`).

### D2: Live Activity updates for chunked downloads

**Decision:** Synthesise a `DownloadProgress`-compatible state inside the per-chunk callback closure and call `LiveActivityManager.updateActivity` directly, using the totals already tracked in the `DownloadItem` (`downloadedSize`, `totalSize`).

**Rationale:** `ChunkCoordinator` has no concept of a progress stream — it signals completion per chunk. Injecting a full `DownloadProgressCoordinator` is overkill; a direct `updateActivity` call with current percentage from `item.downloadedSize / item.totalSize` is simpler and sufficient.

**Alternative considered:** Making `ChunkCoordinator` emit a `ProgressStream` — too much refactoring for a bug-fix change.

### D3: User preference key

**Decision:** Use `@AppStorage("liveActivitiesEnabled")` defaulting to `true`. `LiveActivityManager.startActivity` reads `UserDefaults.standard.bool(forKey: "liveActivitiesEnabled")` (with missing-key treated as `true`) before calling `Activity.request`.

**Rationale:** `AppStorage` wires directly into SwiftUI `SettingsView` with zero boilerplate. Defaulting to `true` preserves existing behaviour for users who haven't visited Settings.

### D4: Tradeoff copy in Settings

**Decision:** Show a two-line secondary label beneath the Live Activity toggle: `"Shows download progress on your Lock Screen and Dynamic Island. May increase battery usage during large downloads."`

**Rationale:** Concise, factually accurate, not alarmist. Gives users enough information to make an informed choice without overwhelming the settings screen.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| `startActivity` called twice (e.g., on resume) | `LiveActivityManager` stores activities by UUID; guard with `activities[id] != nil` check and skip if already active |
| Chunked download Live Activity shows 0% then jumps to chunk-complete increments | Acceptable UX for a bug-fix release; chunk granularity is already 4 MB by default |
| Widget extension `DownloadAttributes` drifts from main target | Document the sync contract; a compiler error in the extension will surface any mismatch later |
| User has Live Activities system-disabled (Settings > [App] > Live Activities) | `ActivityAuthorizationInfo().areActivitiesEnabled` already returns `false` in this case; `startActivity` guard handles it |
| Battery concern from users | Covered by the tradeoff note in Settings; 2-second throttle already limits update frequency |

## Migration Plan

No new persistent state or migrations required. `UserDefaults["liveActivitiesEnabled"]` defaults to `true` (missing key → `true` in `LiveActivityManager`), so existing users see no behaviour change until they explicitly disable it.
