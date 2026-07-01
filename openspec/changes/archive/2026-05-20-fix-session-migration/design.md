## Context

`DownloadEngine` implements a dual-session architecture: foreground `URLSession.default` for speed, background `URLSessionConfiguration.background` for resilience. On `willResignActiveNotification`, active foreground tasks should migrate to the background session via `cancel(byProducingResumeData:)` + `downloadTask(withResumeData:)`.

**Current failure:** The migration is broken. Three distinct bugs cause downloads to show "Cancelled" on backgrounding:

1. **Race condition in `migrateToBackground()`** — `cancel(byProducingResumeData:)` callback fires asynchronously inside a `Task`. iOS suspends the process before the callback executes, so the replacement background task is never created.
2. **`handleError` treats migration cancellation as failure** — Cancelling a task for migration produces `NSURLErrorCancelled`. `handleError` posts `.downloadTaskDidFail`, marking the download as errored.
3. **`ChunkCoordinator` uses ephemeral session** — Chunked downloads run on `URLSession(configuration: .ephemeral)`, which iOS kills entirely on suspension. No migration path exists for in-flight chunks.

## Goals / Non-Goals

**Goals:**
- Downloads survive backgrounding and screen lock without "Cancelled" errors
- Single-stream foreground downloads migrate to background session reliably
- Chunked downloads degrade gracefully to single-stream on background session
- Migration completes before iOS suspends the process

**Non-Goals:**
- Migrating background tasks back to foreground on `didBecomeActive` (current behavior: they stay on background — this is correct)
- Chunked downloads running on background session (background URLSession doesn't support custom `Range` headers well with `downloadTask`)
- Changing chunk download strategy or performance optimization

## Decisions

### 1. Use `beginBackgroundTask` to protect migration window

**Decision:** Call `UIApplication.shared.beginBackgroundTask(expirationHandler:)` in `handleWillResignActive()` before triggering migration. End it after all `restartOnBackground` completions fire.

**Why not `BGProcessingTask`?** Too heavy. We need ~5 seconds, not minutes. `beginBackgroundTask` gives ~30s on most iOS versions — more than enough.

**Why not synchronous cancellation?** `cancel(byProducingResumeData:)` callback is inherently async per Apple API. No synchronous alternative exists.

### 2. Track "migrating" state to suppress cancellation errors

**Decision:** Add a `migratingDownloadIDs: Set<UUID>` to `DownloadEngine`. When migration begins, insert IDs. In `handleError`, if `downloadID` is in the set and error is `NSURLErrorCancelled`, silently ignore. Remove ID from set after `restartOnBackground` completes.

**Alternative considered:** Checking `isAppActive == false` in `handleError`. Rejected because a real cancellation could happen right as the app backgrounds (unrelated user cancel).

### 3. Cancel ChunkCoordinator tasks and fall back to single-stream on backgrounding

**Decision:** Add a `cancelAll()` method to `ChunkCoordinator`. When `willResignActive` fires during a chunked download, cancel the coordinator, persist completed chunks, and start a single-stream download on the background session from byte 0 (resume data won't work for partial chunks).

**Why restart from 0?** Chunk ranges are arbitrary byte splits not aligned with server resume points. The background session's `downloadTask(with:)` is the only reliable option.

**Why not reassemble partial progress?** Ephemeral session data is lost on suspension. Only fully-written `.partN` files on disk are usable, and merging partial + single-stream is complex with no benefit.

### 4. Completion counter for background task expiry

**Decision:** Track pending migration count with an `Int`. Decrement on each `restartOnBackground` completion. When count hits 0, call `endBackgroundTask`. The expiration handler will also end the task and log a warning.

## Risks / Trade-offs

- **Progress reset on chunked→single-stream fallback** → User sees progress drop to 0 for chunked downloads that were migrating. Acceptable trade-off vs. download failure. Mitigated by this being a rare edge case (only happens if user backgrounds during the chunked download phase).
- **`beginBackgroundTask` expiry (30s)** → If migration takes longer (unlikely for 1-3 tasks), expiration handler fires and ends the task. Risk is low — `cancel(byProducingResumeData:)` callback typically fires within milliseconds.
- **Re-download waste** → Chunked downloads that were near completion restart from 0. For very large files this wastes bandwidth. Acceptable because the alternative is complete download failure.
