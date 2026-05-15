## Why

The migration to a background `URLSession` in the `fix-downloads-enhance-ui` change (commit `596cebb`) introduced a severe download speed regression. The background session routes all traffic through the system daemon (`nsurlsessiond`), which adds latency and throughput overhead compared to a foreground session. While this was done to support downloads during screen lock/backgrounding, it degrades performance for the common case — downloads while the app is actively in the foreground.

Two issues compound the problem:
1. **Single-stream downloads are always slow**: Every single-stream download (files that don't support HTTP Range, or files ≤ 4 MB) now goes through the background session, which is inherently slower than `URLSessionConfiguration.default`.
2. **Chunked downloads underutilized**: The `ChunkCoordinator` correctly uses its own ephemeral session for parallel chunk transfers, but the `DownloadEngine.startChunkDownload()` method (which uses the background session) is dead code — creating confusion and a maintenance trap.

## What Changes

- **Dual-session architecture in `DownloadEngine`**: Add a foreground `URLSessionConfiguration.default` session for active downloads alongside the existing background session. Use the foreground session when the app is in the foreground for maximum throughput; automatically hand off to the background session when the app enters background.
- **Remove dead `startChunkDownload` method**: `DownloadEngine.startChunkDownload()` is never called by `ChunkCoordinator` (which uses its own ephemeral session). Remove it to eliminate confusion.
- **App lifecycle observation**: `DownloadEngine` should observe `UIApplication.willResignActiveNotification` and `didBecomeActiveNotification` to switch between foreground and background sessions for active single-stream downloads.
- **Foreground session fallback for short-lived downloads**: Downloads that complete while the app is in the foreground never need to touch the background session at all.

## Capabilities

### New Capabilities
- `dual-session-engine`: Introduce a dual-session architecture in `DownloadEngine` — a foreground `URLSessionConfiguration.default` session for active high-speed downloads and the existing background session for resilience during app suspension. Automatic handoff between sessions based on app lifecycle state.

### Modified Capabilities
- `download-engine`: Modify background session initialization requirements to add a foreground session for speed, and remove the unused `startChunkDownload()` API.

## Impact

- **Files changed**: `Downly/Engine/DownloadEngine.swift` (primary), `Downly/Queue/DownloadQueueManager.swift` (minor — no changes to how it calls the engine)
- **No API changes** to `ChunkCoordinator`, `ChunkManager`, `DownloadQueueManager`, or `DownloadProgressCoordinator` — these all work correctly already
- **Risk**: Foreground-to-background handoff timing must be seamless; a download must not stall or duplicate during the transition
- **Testing**: Compare download speeds on same server/file before and after the fix; verify background downloads still work after screen lock
