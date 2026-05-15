## Context

Downly's download engine was migrated from `URLSessionConfiguration.default` to `URLSessionConfiguration.background(withIdentifier:)` in the `fix-downloads-enhance-ui` change to support downloads during screen lock and app suspension. While this achieved the reliability goal, it introduced a severe throughput regression.

Background URLSession routes all traffic through the system daemon `nsurlsessiond`, which adds overhead: the data path crosses process boundaries, the system may batch or throttle callbacks, and the connection management is opaque. For single-stream downloads (files that don't support HTTP Range, or files ≤ 4 MB), this is the only download path — and it's now significantly slower than the previous foreground session.

The chunked download path (`ChunkCoordinator`) is unaffected because it uses its own ephemeral `URLSession` — but only files that support `Accept-Ranges: bytes` AND exceed 4 MB benefit from this. All other downloads go through the slow background session exclusively.

### Current architecture

- `DownloadEngine` — actor wrapping a **background** `URLSession`. All single-stream downloads and the `startChunkDownload()` method (dead code) use this session.
- `ChunkCoordinator` — actor with its own **ephemeral** `URLSession` for parallel chunk data tasks. Works correctly and at full speed.
- `ChunkManager` — struct with its own **ephemeral** `URLSession` for HEAD probe requests.
- `DownloadQueueManager` — orchestrates downloads, decides chunk vs. single-stream based on `ServerCapability`.

### Key constraints

- Background session support MUST be retained — users expect downloads to survive screen lock.
- The fix must not disrupt `ChunkCoordinator`'s ephemeral session model.
- `DownloadEngine` is an actor with a singleton — session switching must be safe under concurrency.

## Goals / Non-Goals

**Goals:**
- Restore download speed for single-stream downloads to match or exceed the pre-migration `.default` session performance.
- Retain background download capability so downloads survive screen lock and app suspension.
- Remove dead code (`startChunkDownload()`) that creates confusion.
- Seamless foreground ↔ background session handoff with no stalls or data loss.

**Non-Goals:**
- Modifying `ChunkCoordinator` or its ephemeral session (it already works correctly at full speed).
- Changing the chunk size default (4 MB) or the `OperationQueue.maxConcurrentOperationCount` (3).
- Adding Wi-Fi-only mode, download scheduling, or priority controls.
- Modifying the probe/HEAD request logic in `ChunkManager`.

## Decisions

### D1: Dual-session architecture — foreground session for speed, background for resilience

**Decision**: Add a second `URLSessionConfiguration.default` session to `DownloadEngine`. When the app is in the foreground, start new single-stream downloads on the foreground session. When the app moves to background, migrate active downloads to the background session via pause-and-resume-with-data.

**Rationale**: The foreground `.default` session communicates directly with the networking stack in-process, avoiding the `nsurlsessiond` daemon overhead. This restores the original download speed. The background session is only needed when the app is truly suspended.

**Alternatives considered**:
- *Use only foreground session + `UIApplication.beginBackgroundTask`*: `beginBackgroundTask` only provides ~30 seconds of grace. Large files would be killed after suspension. Not sufficient.
- *Use only background session but tune it*: Background session performance is system-controlled. Even with `isDiscretionary = false` and `httpMaximumConnectionsPerHost = 6`, throughput is fundamentally limited by the daemon architecture. No tuning can match foreground session speed.
- *Use `URLSessionConfiguration.default` for everything, with extended background time*: The 30s `beginBackgroundTask` window is not enough for large downloads. The user explicitly needs screen-lock-resilient downloads.

**Implementation notes**:
- The foreground session MUST NOT use a delegate queue — it should use the default serial queue to match current delegate behavior.
- Both sessions share the same `URLSessionDownloadDelegate` (the `DownloadEngine` actor). The `taskDescription` encoding already distinguishes downloads by UUID.
- Track which session each active task is on via a new field in `ActiveTask`.

### D2: App lifecycle-driven session switching

**Decision**: Observe `UIApplication.willResignActiveNotification` and `UIApplication.didBecomeActiveNotification` in `DownloadEngine`. On resign-active, pause all foreground tasks and re-start them on the background session using resume data. On become-active, do nothing — let existing background tasks complete naturally (migrating back would add complexity with minimal benefit).

**Rationale**: The resign-active notification is the last reliable point before the app may be suspended. Pausing and resuming with data preserves the download position. Migrating back on become-active is unnecessary because background tasks already work (just slower).

**Alternatives considered**:
- *Migrate back on become-active*: Adds complexity (cancel background task, get resume data, start foreground task). The benefit is marginal since the download is already in progress. Not worth the risk of data loss.
- *Use `scenePhase` in SwiftUI*: Works in the UI layer but `DownloadEngine` is an actor without SwiftUI access. NotificationCenter is the right mechanism.

**Implementation notes**:
- Downloads that start while the app is already in the background should go directly to the background session.
- Store an `isAppActive` boolean in the actor, updated by lifecycle notifications.
- When migrating a task, the resume data may not be immediately available (server doesn't support it). In this case, cancel the foreground task and start a fresh background task from the beginning — this is acceptable because the migration only happens on app backgrounding.

### D3: Remove dead `startChunkDownload()` method

**Decision**: Delete `DownloadEngine.startChunkDownload()` entirely.

**Rationale**: `ChunkCoordinator` uses its own ephemeral session (`session.data(for:)`) and never calls this method. Its presence creates confusion — it stores `activeTasks` keyed by `downloadID` (not per-chunk), so multiple chunks of the same file would overwrite each other's entries. It's a correctness bug waiting to happen.

### D4: New downloads prefer foreground session, with immediate background fallback

**Decision**: When `startDownload()` is called, check `isAppActive`. If active, create the task on the foreground session. If not active (e.g., download was queued while in background, or `restoreQueueOnLaunch` fires), create it on the background session.

**Rationale**: This ensures the fastest path is always used when possible, with automatic degradation to the background session when the app cannot remain in the foreground.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Pause-and-resume during migration may lose a few seconds of download progress if resume data isn't immediately available | Accept the minor re-download. The speed gain in foreground vastly outweighs occasional resume overhead on backgrounding. |
| Two URLSessions increase memory and connection usage | The foreground session is only active while the app is in the foreground. Memory overhead is minimal (~KB for the session object). |
| Race condition: lifecycle notification arrives while a download is mid-callback | Actor serialization in `DownloadEngine` eliminates races. The notification handler and delegate callbacks all go through the actor's serial executor. |
| `resumeData` may not be available for all servers | Fall back to restarting the download from scratch on the background session. The user loses progress but the download continues. This matches the current behavior for pause/resume. |
| Foreground downloads die if the user force-kills the app (unlike background session) | This is expected behavior. Force-kill is the user's intent to stop. The download can be resumed on next launch via `restoreQueueOnLaunch()`. |
