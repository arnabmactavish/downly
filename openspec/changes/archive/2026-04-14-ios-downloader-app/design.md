## Context

Downly is a greenfield native iOS application. There are no legacy systems to migrate. The design must operate within iOS's enforced resource constraints: background execution time is system-controlled, multi-connection downloading is limited by iOS networking policies, and SwiftData writes must be throttled to avoid I/O contention. The target deployment is iOS 17+, enabling full use of SwiftData, ActivityKit, and the latest URLSession background transfer improvements.

## Goals / Non-Goals

**Goals:**
- Deliver reliable file downloads that survive app termination and device restarts
- Achieve higher throughput than single-connection downloads via HTTP Range-based chunking where supported
- Persist all download state durably in SwiftData with minimal write overhead
- Provide real-time progress feedback on the main UI and via Live Activities
- Enforce a clean concurrency model (max 3 active downloads, max 6 concurrent chunks per download)
- Build a fully native UI aligned with Liquid Glass design principles

**Non-Goals:**
- Cloud sync or cross-device handoff (deferred to a future phase)
- Download scheduling (WiFi-only, time-based) — future phase
- In-app file preview or playback
- Browser-extension integration or share-sheet capture (may be added later)
- Supporting iOS versions below 17

## Decisions

### Decision 1 — SwiftData for persistence, not Core Data or SQLite

**Choice**: SwiftData  
**Rationale**: SwiftData provides native Swift model declarations, automatic model migrations, and tight SwiftUI integration — all without the NSManagedObject boilerplate of Core Data. It is the strategic Apple persistence API for iOS 17+.  
**Alternatives considered**:
- Core Data: More mature but significantly more verbose; offers no meaningful advantage for this schema.
- SQLite + GRDB: Fine for performance but adds a third-party dependency and manual migration management.

### Decision 2 — URLSession background configuration, not foreground session

**Choice**: `URLSessionConfiguration.background(withIdentifier:)` for all downloads  
**Rationale**: Background sessions allow downloads to continue when the app is suspended or killed. The `urlSession(_:downloadTask:didFinishDownloadingTo:)` delegate is called even after relaunch, providing a consistent completion path.  
**Alternatives considered**:
- Default session: Simpler, but all in-flight transfers are cancelled when the app is backgrounded.
- Foreground + beginBackgroundTask: Unreliable after ~30 s of app suspension; Apple can terminate the task.

### Decision 3 — HTTP Range-based chunking via parallel URLSessionDownloadTask instances

**Choice**: One URLSessionDownloadTask per chunk, limited to 6 concurrent chunk tasks per download  
**Rationale**: Parallel byte-range requests can saturate higher-bandwidth connections. Each chunk is a standard download task, meaning resumeData works on a per-chunk basis.  
**Alternatives considered**:
- Single-task with byte-range: No parallelism benefit; defeats the purpose of chunking.
- Custom networking (NWConnection/Network.framework): More control but far more complexity and no native resume support.

### Decision 4 — OperationQueue for download-level concurrency, URLSession for chunk-level

**Choice**: Two-tier concurrency model — `OperationQueue` (max 3) at the download level, wrapping chunk task groups (max 6) inside each download operation  
**Rationale**: Separates the concerns of "how many downloads at once" (OperationQueue) from "how many byte-range requests for a single file" (chunk group). This makes pause/resume at the download level straightforward: cancel the operation, retain resumeData for each in-flight chunk.  
**Alternatives considered**:
- Swift Concurrency TaskGroup only: Elegant but loses the KVO-friendly state machine that OperationQueue provides, which the UI layer relies on.
- Single global URLSession with all chunk tasks: Works but makes it harder to associate tasks with a specific download item and slows cancellation.

### Decision 5 — FileHandle streaming merge, not Data accumulation

**Choice**: `FileHandle.write()` in a loop to stream-merge chunk temp files into the final output  
**Rationale**: Files can be multiple gigabytes. Loading all chunks into memory as `Data` before writing is infeasible. FileHandle enables constant-memory sequential merging.  
**Alternatives considered**:
- `FileManager.createFile(atPath:contents:)`: Holds entire content in memory.
- Shell `cat` via `Process`: Works but unsafe for App Store submission (sandboxing).

### Decision 6 — ActivityKit Live Activities for progress, not Notification-based UX

**Choice**: ActivityKit `Activity<DownloadAttributes>` with periodic content updates  
**Rationale**: Live Activities surface real-time progress on the Lock Screen and Dynamic Island without requiring the user to open the app. Push updates via `Activity.update()` keep battery impact low.  
**Alternatives considered**:
- UNUserNotificationCenter progress notifications: Not interactive; notifications are not updated in real time.
- Widget-only: Cannot animate progress continuously.

### Decision 7 — SwiftUI + UIKit hybrid for the main UI

**Choice**: SwiftUI for list views, navigation, and modals; UIKit `UIVisualEffectView` for the Liquid Glass blur layers  
**Rationale**: SwiftUI delivers reactive updates from `@Query` (SwiftData) out of the box. UIKit blur APIs give full control over `UIBlurEffect` style and intensity that SwiftUI's `.background(.ultraThinMaterial)` doesn't always expose cleanly.  
**Alternatives considered**:
- Pure SwiftUI: `.background(.ultraThinMaterial)` is good enough for most surfaces; avoids UIKit bridging complexity. Final choice leans SwiftUI-primary with targeted UIKit bridging only for the floating navigation bar.
- Pure UIKit: More lines of code for reactive SwiftData observation; no practical advantage.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| iOS may coalesce or defer background session callbacks under low battery / Low Power Mode | Use `isDiscretionary = false` for user-initiated downloads; show user-visible status via Live Activity rather than relying on immediate callback timing |
| Server may not support `Accept-Ranges`, breaking chunked path | Send HEAD request first; fall back to single-stream download transparently |
| Chunk temp files can accumulate unboundedly on crash mid-merge | Add a cleanup sweep at app launch that deletes temp files for any download in `failed` or `interrupted` state |
| SwiftData write storms from high-frequency progress callbacks | Throttle persistence writes to 1 s intervals or +1% progress gate; update in-memory state immediately for UI, persist lazily |
| ActivityKit Live Activity is denied or unsupported (older device) | Wrap all ActivityKit calls in `#available(iOS 16.2, *)` guards; degrade gracefully to no Live Activity |
| Merging a multi-GB file on a low-storage device | Check available disk space (via `FileManager.temporaryDirectory` volume attributes) before starting merge; surface error if insufficient |
| iOS URL validation / ATS (App Transport Security) blocks plain HTTP URLs | Warn users; provide a setting to allow non-HTTPS URLs (NSAllowsArbitraryLoads — document the trade-off clearly) |

## Migration Plan

This is a new application with no existing users or data. No migration is required for the initial release. Future schema migrations will be handled automatically by SwiftData's `.migration` model version system.

## Open Questions

- **Chunk size defaults**: Should chunk size be user-configurable in Settings, or fixed at 4 MB? (Recommend configurable: 1 MB / 4 MB / 8 MB)
- **Background session identifier scope**: Should one shared background session identifier cover all downloads, or one identifier per download? (Recommend: single shared identifier for simplicity; per-download identifiers complicate session re-association on relaunch)
- **App Group for Live Activity widget extension**: Confirm App Group ID to be used for shared SwiftData store access between main app and Live Activity widget extension
- **File storage destination**: Should the default save location be the app's Documents directory (user-accessible via Files app) or a private container? (Recommend: Documents directory for discoverability)
