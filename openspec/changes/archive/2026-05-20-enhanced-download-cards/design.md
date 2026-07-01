## Context

Downly's download cards (`DownloadItemCard`) currently have minimal interaction: inline action buttons (pause/resume/cancel/retry) and tap-on-error to show `ErrorDetailSheet`. No swipe gestures, no long press context menu, no multi-select via gesture, and no way to update an expired URL without re-adding the download.

Existing edit mode in `DownloadListView` uses a toggle button + checkboxes + floating delete FAB — functional but doesn't match Apple's native two-finger selection gesture.

URL is stored as mutable `var url: String` on `DownloadItem` (SwiftData), so schema supports updates. Resume data is stored as `Data?`. `DownloadQueueManager` has no `updateURL` API.

## Goals / Non-Goals

**Goals:**
- Add five card interaction enhancements that bring UX to iOS-native quality
- URL update/resume: let users fix expired URLs without losing downloaded bytes
- Swipe-to-delete: standard iOS destructive swipe gesture
- Two-finger multi-select: Apple-native rapid selection pattern
- Long press context menu: contextual actions based on download state
- Tap detail sheet: rich bottom sheet with download info and animated progress visualization

**Non-Goals:**
- Drag-to-reorder cards (priority system — future work)
- Background download URL auto-refresh (server-side token renewal)
- Download speed graph history persistence (in-memory only for current session)
- Batch URL update for multiple downloads

## Decisions

### 1. Swipe-to-Delete: `.swipeActions` modifier vs custom `DragGesture`

**Decision**: Use native SwiftUI `.swipeActions(edge: .trailing)` on each card.

**Why**: Native modifier handles gesture conflicts, accessibility, haptics, and visual consistency automatically. Custom `DragGesture` requires reimplementing all of that and risks conflicting with `ScrollView` gestures.

**Trade-off**: Less visual customization than custom gesture — but consistency with iOS conventions outweighs custom styling here.

### 2. Multi-Select: `UIKit` two-finger pan via `UIViewRepresentable` 

**Decision**: Use `UIPanGestureRecognizer` with `minimumNumberOfTouches = 2` bridged via `UIViewRepresentable` overlay on the list container.

**Why**: SwiftUI has no native two-finger pan gesture. Apple's own apps (Mail, Notes, Files) use UIKit's `allowsMultipleSelectionDuringEditing` on `UITableView` — but we're in SwiftUI with `LazyVStack` not `List`. Bridging a `UIPanGestureRecognizer` gives us the raw two-finger tracking; we then hit-test against card frames to determine selection.

**Alternatives considered**:
- SwiftUI `List` with `.environment(\.editMode)` — loses our custom card design and liquid glass styling
- `MagnifyGesture` hack — unreliable and semantically wrong

### 3. Context Menu: Native `.contextMenu` modifier

**Decision**: Use SwiftUI's `.contextMenu` with state-conditional menu items.

**Why**: Native context menu provides correct haptic, preview lift, blur backdrop, and accessibility. Menu items are built dynamically per download state (e.g., show "Pause" only when running, "Update URL" only when error/paused).

### 4. URL Update Resume Strategy

**Decision**: HEAD-request validation → update URL on `DownloadItem` → resume with byte offset via `Range` header (not `resumeData`).

**Why**: `resumeData` from `URLSession` encodes the original URL internally — it cannot be repointed to a new URL. Instead, we store `downloadedSize` and use a `Range: bytes=<downloadedSize>-` header on the new URL. A HEAD request to the new URL first validates that the server accepts range requests and the content length is compatible.

**Flow**:
1. User provides new URL (via context menu "Update URL" or detail sheet)
2. HEAD request to new URL → check `Accept-Ranges: bytes` and `Content-Length`
3. If `Content-Length` matches (or is >= `downloadedSize`): update `DownloadItem.url`, clear `resumeData`, set status to `.paused`
4. User manually resumes → engine starts with `Range` header from `downloadedSize`
5. If incompatible: show alert explaining mismatch, offer "Start Fresh" option

**Risk**: New URL may serve different content with same size. No checksum validation (non-goal for v1).

### 5. Detail Sheet: SwiftUI `.sheet` with `presentationDetents`

**Decision**: Use `.sheet` with `.presentationDetents([.medium, .large])` for the detail bottom sheet. Medium shows overview; drag to large for full details + speed graph.

**Why**: Native sheet with detents gives correct iOS 16+ bottom-sheet behavior including drag-to-dismiss, spring physics, and background dimming. Custom `GeometryReader` sheets are fragile.

### 6. Speed Graph: Swift Charts `LineMark` with rolling window

**Decision**: Use Swift Charts framework. Store last 60 speed samples (1/sec) in a ring buffer on the ViewModel. Display as area chart with gradient fill.

**Why**: Swift Charts is native, performant, and styled to match iOS design language. No external charting dependency needed.

## Risks / Trade-offs

- **Two-finger gesture conflicts with scroll** → Mitigation: `UIPanGestureRecognizer` with `minimumNumberOfTouches = 2` naturally avoids single-finger scroll. Set `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)` carefully.
- **URL update content mismatch** → Mitigation: HEAD validation + user warning. V1 accepts size-match as "good enough." Future: optional checksum comparison.
- **Resume data invalidation on URL change** → Mitigation: explicitly clear `resumeData` and fall back to Range-header resume. Document that chunked downloads with partial chunks will lose chunk-level progress (restart chunks from their range start).
- **Context menu + tap gesture conflict** → Mitigation: `.contextMenu` is handled by the system before `onTapGesture`; no conflict. Tap opens detail sheet, long press opens menu.
- **Performance of 60-sample speed graph updating 1/sec** → Mitigation: Swift Charts handles this efficiently; ring buffer avoids allocation churn.

## Open Questions

None — all five features have clear implementation paths with native SwiftUI/UIKit primitives.
