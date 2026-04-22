## Context

Downly's download subsystem is built across three layers:

1. **DownloadEngine** — URLSession delegate actor, issues tasks, fires delegate callbacks
2. **DownloadQueueManager** — orchestration actor, drives state transitions, routes to chunked vs. single-stream path, writes to SwiftData
3. **DownloadProgressCoordinator** — subscriber that fans progress events into SwiftData and Live Activity

After several rounds of iteration the code compiles and runs, but downloads produce no output. Diagnostic inspection reveals the following root causes:

**Bug A — Wrong URLSession type for single-stream downloads:**
The `DownloadEngine` uses a `URLSession.background(...)` session. Background sessions require the app to adopt Apple's background transfer entitlement and use a special OS-managed queue; they do NOT deliver `didWriteData` progress callbacks reliably to the app process while it is in the foreground, and in the Simulator they frequently silently fail to start. Chunked downloads bypass the background session entirely (they use an ephemeral session inside `ChunkCoordinator`), so the problem is isolated to the single-stream path.

**Bug B — Temp file staging path is not durable:**
`handleCompletion` copies the URLSession-provided temp file to `FileManager.default.temporaryDirectory`. That directory is managed by iOS and can be purged at any moment — including before `waitForSingleStreamCompletion` executes `moveItem`. The move silently fails and the download appears "completed" (status updated) but no file exists.

**Bug C — DownloadProgressCoordinator is never wired:**
`DownloadProgressCoordinator` exists but `DownloadQueueManager.executeDownload()` ignores the `ProgressStream` returned by `engine.startDownload()`. The stream is simply discarded (`_ = await engine.startDownload(...)`). No progress events propagate to SwiftData, so `downloadedSize`, `totalSize`, and speed never update in the UI.

**Bug D — Files app cannot see downloaded files:**
`Info.plist` is missing `UIFileSharingEnabled` (`YES`) and `LSSupportsOpeningDocumentsInPlace` (`YES`). Without these keys, the app's `Documents/` folder is hidden from the Files app.

**Bug E — No debug visibility:**
There is no structured logging to identify which step fails at runtime. `os.Logger` is available but unused.

## Goals / Non-Goals

**Goals:**

- Single-stream downloads complete successfully and the file appears in the app's Documents folder, visible via the iOS Files app.
- `totalSize` (from HEAD response), `downloadedSize` (from progress events), and speed are all reflected in the UI while a download is running.
- Debug builds print structured download lifecycle logs to the Xcode console.
- The fix is surgical — no architecture changes, no networking library additions.

**Non-Goals:**

- Fixing chunked downloads (they already use an ephemeral session and reportedly work, per code audit).
- Implementing a background download entitlement / true background session support (future work).
- Changing the UI beyond what is necessary to display correct data.

## Decisions

### Decision 1 — Replace background URLSession with a default (foreground) session in DownloadEngine

**Rationale:** Background sessions require explicit entitlement setup, App Group shared containers usable from extensions, and are incompatible with the Simulator's download simulation. The existing implementation never acquired the background entitlement, so it silently does nothing. A `URLSessionConfiguration.default` session delivers delegate callbacks synchronously while the app is in the foreground and is sufficient for the app's current use case (foreground-initiated downloads with progress shown in the UI).

**Alternative considered:** Keep the background session but add the entitlement and a proper delegate queue. Rejected because it requires provisioning profile changes, adds significant complexity, and still wouldn't fix progress callbacks in the Simulator.

**Kept from existing design:** The `handleEventsForBackgroundURLSession` AppDelegate hook and `storeBackgroundCompletionHandler` are retained as no-ops for now, preserving the architecture for a future background-download change.

### Decision 2 — Use App Group `Documents/` as the stable staging area

**Rationale:** The App Group shared container is already used for the SwiftData store (`AppModelContainer`). Using the same container's `Documents/` subfolder for downloaded files ensures:
1. Files appear in the iOS Files app when `UIFileSharingEnabled = YES`.
2. The path survives app reinstalls if the App Group container is backed up.
3. No new directory needs to be created (App Group container always exists).

The existing `documentsURL` helper in `DownloadQueueManager` uses `FileManager.default.urls(for: .documentDirectory)` — the app-sandbox Documents, not the App Group Documents. The fix replaces it with the App Group container path.

**Alternative considered:** Keep using the app-sandbox Documents. Rejected because Files app visibility for App Group paths is simpler to configure with the two Info.plist keys.

### Decision 3 — Wire DownloadProgressCoordinator inside executeDownload

**Rationale:** `DownloadProgressCoordinator` is already designed to bridge from `ProgressStream` → SwiftData + LiveActivity. It just needs to be instantiated once per download and handed the stream returned by `engine.startDownload()`. No new code is needed — just wiring.

### Decision 4 — Introduce DownlyLogger with #if DEBUG guard

**Rationale:** `os.Logger` is the Apple-recommended structured logging API. It is always compiled in but log visibility is controlled by the system's log level. For developer console visibility during debugging we additionally call `print()` inside `#if DEBUG` blocks so logs appear in the Xcode output pane without requiring Console.app. In release builds the `print()` calls are compiled out entirely. This pattern keeps release builds performant and clean.

## Risks / Trade-offs

- **Switching from background to default URLSession** means in-progress downloads are cancelled if the app enters the background. This is a known trade-off accepted scope, and users will be informed via a future Live Activity / background mode task. The current UX already has no indication of background progress.

- **App Group Documents vs app-sandbox Documents** — A one-time migration is not needed since there are no existing completed downloads (the bug prevented any from completing). New installs start fresh.

- **Info.plist keys** — `LSSupportsOpeningDocumentsInPlace` makes the app appear as a document provider in Open In… sheets, which may be unexpected. This is low-risk for a download manager app.

## Migration Plan

1. No data migration required — SwiftData schema is unchanged.
2. No entitlement changes required — App Group entitlement already exists.
3. Xcode scheme: no changes to build settings required.
4. Existing tests: none exist; integration verified by running the app and downloading a file.

## Open Questions

- Should there be a maximum per-file size for the foreground download path before the user is prompted to enable background transfer? Deferred to future change.
- Should the download destination be user-configurable (e.g., pick a folder in Files)? Deferred.
