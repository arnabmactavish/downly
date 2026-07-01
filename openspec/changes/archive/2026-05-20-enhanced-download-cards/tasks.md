## 1. Foundation & Models

- [x] 1.1 Add `DownloadQueueError` enum with `downloadMustBePaused`, `urlNotCompatible(reason:)` cases to `DownloadQueueManager.swift`
- [x] 1.2 Add `updateURL(id:newURL:resetProgress:)` async throws method to `DownloadQueueManager` — HEAD validation, URL swap, resumeData clear, chunk reset
- [x] 1.3 Add `SpeedSample` struct and `SpeedHistory` ring buffer (60 samples) to support detail sheet speed graph
- [x] 1.4 Extend `DownloadProgressCoordinator` to record speed samples into `SpeedHistory` per download ID

## 2. Swipe-to-Delete

- [x] 2.1 Add `.swipeActions(edge: .trailing, allowsFullSwipe: true)` to `DownloadItemCard` in `DownloadListView` with red trash button
- [x] 2.2 Add delete confirmation alert triggered by swipe action
- [x] 2.3 Wire confirmation to `DownloadQueueManager.cancelDownload` (active) or direct SwiftData delete (completed — preserve file)

## 3. Context Menu (Long Press)

- [x] 3.1 Create `DownloadContextMenu` view builder that returns state-appropriate menu items
- [x] 3.2 Add `.contextMenu(menuItems:preview:)` modifier to `DownloadItemCard`
- [x] 3.3 Implement Copy URL action (clipboard + haptic)
- [x] 3.4 Implement Share URL action (UIActivityViewController via `ShareLink` or representable)
- [x] 3.5 Implement Share File action for completed downloads
- [x] 3.6 Wire Pause/Resume/Retry/Cancel menu items to existing `DownloadQueueManager` methods
- [x] 3.7 Wire "Update URL" menu item to present URL update sheet

## 4. URL Update & Resume

- [x] 4.1 Create `UpdateURLSheet` SwiftUI view — text field with clipboard auto-populate, validate button, loading state
- [x] 4.2 Integrate HEAD request validation in sheet — show success/error/mismatch states
- [x] 4.3 Add "Start Fresh" option when server is incompatible (reset progress flow)
- [x] 4.4 Verify resume-from-offset works with new URL — `DownloadEngine` sends `Range: bytes=<offset>-` header
- [x] 4.5 Handle chunked download URL update — reset incomplete `ChunkRecord` statuses in `ChunkCoordinator`

## 5. Two-Finger Multi-Select

- [x] 5.1 Create `TwoFingerPanGestureRecognizer` UIKit gesture recognizer with `minimumNumberOfTouches = 2`
- [x] 5.2 Create `TwoFingerPanOverlay` UIViewRepresentable that bridges gesture to SwiftUI
- [x] 5.3 Implement hit-testing logic — map gesture Y position to card indices using `GeometryReader` / preference keys
- [x] 5.4 Wire gesture to existing `isEditing` / `selectedItems` state in `DownloadListView`
- [x] 5.5 Add selection checkbox appearance to `DownloadItemCard` when in selection mode
- [x] 5.6 Add floating selection toolbar — count display, "Select All", "Done" buttons
- [x] 5.7 Add batch actions to selection toolbar — Delete All, Pause All, Resume All

## 6. Detail Bottom Sheet (Tap)

- [x] 6.1 Create `DownloadDetailSheet` SwiftUI view with `.presentationDetents([.medium, .large])`
- [x] 6.2 Implement medium detent content — file info, URL, size, progress, status, dates, action buttons
- [x] 6.3 Implement large detent content — speed graph area, chunk breakdown, error details, file location
- [x] 6.4 Build speed history graph using Swift Charts `AreaMark` with gradient fill and 1/sec updates
- [x] 6.5 Build circular progress ring with animated gradient stroke
- [x] 6.6 Add completion celebration animation (confetti/particle effect on first open of completed download)
- [x] 6.7 Add state-appropriate action buttons at bottom of sheet (Pause/Resume/Retry/Update URL/Open/Share)
- [x] 6.8 Replace existing error-only `onTapGesture` + `ErrorDetailSheet` with universal tap → `DownloadDetailSheet`

## 7. Integration & Polish

- [x] 7.1 Add new design tokens to `DesignSystem.swift` — selection highlight color, context menu tints, detail sheet styling
- [x] 7.2 Ensure gesture priority: context menu (long press) > swipe (horizontal) > tap (detail sheet) > two-finger pan (selection)
- [x] 7.3 Add haptic feedback for selection toggle, swipe threshold, and context menu appearance
- [x] 7.4 Test all interactions in combination — verify no gesture conflicts
- [x] 7.5 Verify URL update + resume end-to-end with both single-stream and chunked downloads
- [x] 7.6 Verify two-finger selection works correctly with `LazyVStack` scrolling
