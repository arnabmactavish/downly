## Why

Download cards currently have minimal interaction — only tap-on-error and inline action buttons. Users lack intuitive gestures (swipe, long press, multi-select) that iOS users expect from list-based interfaces. Additionally, when a download URL expires mid-download, the only option is to cancel and re-add — losing all progress. These gaps hurt usability and make the app feel unfinished.

## What Changes

- **URL Update & Resume**: Allow users to supply a new URL for a failed/paused download, resuming from existing progress (byte offset) with minimal data loss
- **Swipe-to-Delete**: Left swipe on download card reveals trash action, matching standard iOS list patterns
- **Two-Finger Multi-Select**: Two-finger pan gesture activates selection mode, selecting cards as fingers slide — matching Apple's native list behavior
- **Long Press Context Menu**: Long press on download card shows contextual menu (pause/resume, retry, copy URL, update URL, delete, share)
- **Tap Detail Sheet**: Tapping a download card opens a bottom sheet with detailed info — file metadata, progress graph/animation, speed history, and download timeline

## Capabilities

### New Capabilities
- `url-update-resume`: Mechanism to update a download's URL and resume from existing byte offset, including server compatibility validation
- `swipe-to-delete`: Left swipe gesture on download cards revealing destructive delete action with confirmation
- `multi-select-gesture`: Two-finger pan gesture for rapid card selection, integrating with existing edit mode
- `card-context-menu`: Long press context menu with contextual actions based on download state
- `card-detail-sheet`: Bottom sheet presenting detailed download information with animated progress visualization

### Modified Capabilities
- `download-ui`: Card interaction model changes — tap behavior shifts from error-only sheet to universal detail sheet; action buttons may be simplified since context menu provides alternative access
- `download-queue`: Queue manager needs `updateURL(id:newURL:)` API for URL replacement with resume validation

## Impact

- **UI Layer**: `DownloadItemCard.swift` — major gesture/interaction overhaul; `DownloadListView.swift` — multi-select integration; new sheet views
- **Queue Layer**: `DownloadQueueManager.swift` — new `updateURL` method with HEAD validation
- **Engine Layer**: `DownloadEngine.swift` — may need to handle URL change for active/paused downloads with existing resume data
- **Models**: `DownloadItem.swift` — URL is already mutable (`var url: String`), no schema change needed
- **Design System**: `DesignSystem.swift` — new tokens for context menu styling, detail sheet, and selection state
- **Dependencies**: No new external dependencies; uses native SwiftUI gestures and `.contextMenu`
