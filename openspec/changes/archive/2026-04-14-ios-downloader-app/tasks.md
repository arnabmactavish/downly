## 1. Project Setup & Configuration

- [x] 1.1 Create Xcode project named "Downly" (iOS 17+, SwiftUI lifecycle, Swift)
- [x] 1.2 Add required entitlements: Background Modes (Background fetch, Remote notifications), App Groups
- [x] 1.3 Configure Info.plist with NSAllowsArbitraryLoads warning and Background URL session keys
- [x] 1.4 Create App Group identifier and configure shared container for Live Activity extension data access
- [x] 1.5 Add a Live Activity Widget Extension target to the Xcode project
- [x] 1.6 Set up folder structure: `Engine/`, `Queue/`, `Assembly/`, `Persistence/`, `LiveActivity/`, `UI/`, `Models/`

## 2. SwiftData Persistence Layer

- [x] 2.1 Define `DownloadStatus` enum with cases: `pending`, `running`, `paused`, `completed`, `error`, `interrupted`
- [x] 2.2 Define `ChunkStatus` enum with cases: `pending`, `downloading`, `completed`, `failed`
- [x] 2.3 Define `@Model class DownloadItem` with fields: id, url, fileName, totalSize, downloadedSize, status, resumeData, createdAt, updatedAt, errorMessage, chunkSize
- [x] 2.4 Define `@Model class ChunkRecord` with fields: index, rangeStart, rangeEnd, status, tempFilePath, and relationship to `DownloadItem`
- [x] 2.5 Configure `ModelContainer` in the `@main` App struct with the current schema version (v1)
- [x] 2.6 Implement `PersistenceThrottle` actor that buffers progress updates and commits to SwiftData at max once per second or on +1% progress gate
- [x] 2.7 Write unit tests for throttle logic (verify write frequency under rapid update simulation)

## 3. Download Engine (URLSession)

- [x] 3.1 Create `DownloadEngine` actor with a single shared `URLSession` using `URLSessionConfiguration.background(withIdentifier: "com.downly.background-session")`
- [x] 3.2 Implement `URLSessionDownloadDelegate` conformance: `didWriteData`, `didFinishDownloadingTo`, `didCompleteWithError`
- [x] 3.3 Implement progress delivery — coalesce delegate callbacks and notify observers at most once per 0.5 s via `AsyncStream` or `Combine`
- [x] 3.4 Implement `pauseDownload(item:)` — call `cancel(byProducingResumeData:)` and persist resumeData in SwiftData
- [x] 3.5 Implement `resumeDownload(item:)` — use `downloadTask(withResumeData:)` if resumeData exists, else restart from scratch
- [x] 3.6 Implement exponential-backoff retry logic: on transient error, retry up to 3 times with delays of 2 s / 4 s / 8 s
- [x] 3.7 Handle app relaunch: on `application(_:handleEventsForBackgroundURLSession:completionHandler:)`, reconstruct the session and store the completion handler
- [x] 3.8 Call the background session completion handler in `urlSessionDidFinishEvents(forBackgroundURLSession:)`

## 4. Chunk Manager

- [x] 4.1 Implement `ChunkManager` struct with `func analyzeServer(url: URL) async throws -> ServerCapability` that sends a HEAD request and parses `Accept-Ranges` and `Content-Length` headers
- [x] 4.2 Implement `func splitIntoChunks(totalSize: Int64, chunkSize: Int) -> [ChunkRange]` that produces `[(start: Int64, end: Int64)]` byte-range tuples
- [x] 4.3 Implement single-chunk download task creation with `Range: bytes=start-end` HTTP header injection
- [x] 4.4 Create `ChunkCoordinator` that launches up to 6 concurrent chunk download tasks per download using Swift concurrency `withTaskGroup`
- [x] 4.5 Implement chunk retry logic: retry individual failed chunks up to 3 times before promoting to download-level error
- [x] 4.6 Implement fallback: if 2+ chunks fail permanently, cancel all remaining chunks and signal download engine to restart as single-stream
- [x] 4.7 Write unit tests for `splitIntoChunks` covering even division, uneven division, and single-chunk edge cases

## 5. File Assembly Engine

- [x] 5.1 Implement `DiskSpaceChecker` — query `FileManager` volume attributes for available bytes and compare against 110% of expected file size
- [x] 5.2 Implement `FileAssemblyEngine` with `func merge(chunks: [ChunkRecord], into outputURL: URL) async throws`
- [x] 5.3 In merge: open output `FileHandle` for writing, iterate chunks in ascending `index` order, stream-write each chunk file via `FileHandle.write()`, close all handles
- [x] 5.4 Implement file size validation post-merge: compare `FileManager.attributesOfItem(atPath:)[.size]` against expected `totalSize`
- [x] 5.5 Implement temp file cleanup: delete all `.partN` temp files on successful merge or on download cancellation/failure
- [x] 5.6 Implement app-launch orphan cleanup: scan temp directory for `.partN` files whose associated download is no longer in a pending/active state and delete them
- [x] 5.7 Write integration test for merge correctness using synthetic chunk temp files

## 6. Download Queue Manager

- [x] 6.1 Create `DownloadQueueManager` class (or actor) wrapping an `OperationQueue` with `maxConcurrentOperationCount = 3`
- [x] 6.2 Implement `DownloadOperation: AsyncOperation` that encapsulates a full download lifecycle (chunk detection → chunk downloads → merge → completion)
- [x] 6.3 Implement state machine transitions with guarded validity checks (reject invalid transitions)
- [x] 6.4 Implement `addDownload(url:fileName:)` — creates SwiftData record, creates `DownloadOperation`, enqueues it
- [x] 6.5 Implement `pauseDownload(id:)` — suspends the associated operation and updates state to `.paused`
- [x] 6.6 Implement `resumeDownload(id:)` — re-enqueues the operation from paused state
- [x] 6.7 Implement `cancelDownload(id:)` — cancels and removes the operation, cleans up temp files and SwiftData record
- [x] 6.8 Implement `restoreQueueOnLaunch()` — on app start, fetch all `.pending` and `.interrupted` items from SwiftData and re-enqueue them

## 7. Live Activity (ActivityKit)

- [x] 7.1 Define `DownloadAttributes: ActivityAttributes` with static fields: `downloadID` (UUID), `fileName` (String)
- [x] 7.2 Define `DownloadAttributes.ContentState: Encodable, Hashable` with: `progressPercent` (Double), `speedBytesPerSecond` (Int64), `estimatedSecondsRemaining` (Int?), `status` (DownloadStatus)
- [x] 7.3 Implement `LiveActivityManager` actor with `func startActivity(for item: DownloadItem) async` guarded by `#available(iOS 16.2, *)` and `ActivityAuthorizationInfo().areActivitiesEnabled`
- [x] 7.4 Implement `func updateActivity(id: UUID, state: ContentState) async` that calls `activity.update(using:)` throttled to max once per 2 s
- [x] 7.5 Implement `func endActivity(id: UUID, policy: ActivityUIDismissalPolicy) async` — called on `.completed` (policy: .after 5 s) and `.error` (policy: .immediate)
- [x] 7.6 Build the Live Activity widget UI in the Widget Extension target: show file name, progress ring/bar, speed, ETA, and status icon for Lock Screen and Dynamic Island compact/expanded views
- [x] 7.7 Register the Widget Extension in the main app and confirm App Group data sharing works

## 8. UI Layer — Design System

- [x] 8.1 Define color palette, typography (SF Pro), and spacing tokens in a `DesignSystem.swift` constants enum
- [x] 8.2 Implement `LiquidGlassBackground` ViewModifier that applies `.ultraThinMaterial` blur + semi-transparent overlay + rounded corners
- [x] 8.3 Implement `FloatingBottomNavBar` SwiftUI view: 5 tabs (All/Downloading/Paused/Done/Error), pill shape, floating above content with safe-area padding
- [x] 8.4 Implement `FloatingOvalButton` SwiftUI view used for Edit and Settings top controls
- [x] 8.5 Implement `AddDownloadFAB` — circular floating action button with `+` icon, placed above bottom nav bar
- [x] 8.6 Implement spring animation helper (`withSpringAnimation`) for all state-change transitions

## 9. UI Layer — Screens & Components

- [x] 9.1 Implement `DownloadListView` — SwiftUI view using `@Query` to observe `DownloadItem` records, filtered by selected tab state
- [x] 9.2 Implement `DownloadItemCard` SwiftUI view displaying: fileName, totalSize, downloadedSize, remainingSize, progressPercent, speed, status, and contextual action buttons (Pause/Resume/Cancel/Retry)
- [x] 9.3 Implement animated `ProgressBar` within `DownloadItemCard` that smoothly updates via `withAnimation`
- [x] 9.4 Implement `AddDownloadSheet` — modal sheet with URL text field (pre-populated from clipboard), file name field, Start/Cancel buttons
- [x] 9.5 Implement clipboard URL detection in `AddDownloadSheet.onAppear` using `UIPasteboard.general.url`
- [x] 9.6 Implement `SettingsView` — modal screen with chunk size selector (1 MB / 4 MB / 8 MB), max concurrent downloads setting, and storage info
- [x] 9.7 Implement edit mode: multi-select + bulk delete triggered by the Edit floating button
- [x] 9.8 Implement visual state variants for `DownloadItemCard`: running (animated), paused (dimmed), completed (green checkmark), error (red indicator + Retry button)

## 10. Integration & Download Lifecycle Wiring

- [x] 10.1 Wire `AddDownloadSheet` → `DownloadQueueManager.addDownload(url:fileName:)` → pre-flight disk space check → SwiftData record creation
- [x] 10.2 Wire `DownloadEngine` progress callbacks → `PersistenceThrottle` → SwiftData writes → `@Query` auto-refresh in `DownloadListView`
- [x] 10.3 Wire `DownloadEngine` completion → `FileAssemblyEngine.merge()` → validation → status update → `LiveActivityManager.endActivity()`
- [x] 10.4 Wire error path: retry exhaustion → `.error` status → LiveActivity end → error card shown in UI
- [x] 10.5 Wire `DownloadQueueManager.restoreQueueOnLaunch()` call in `App.init()` or `.onAppear` of root view
- [x] 10.6 Wire background session events in `AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)`

## 11. Quality Assurance & Polish

- [ ] 11.1 Test chunked download with a server known to support `Accept-Ranges` (e.g., a large file on a CDN)
- [ ] 11.2 Test fallback to single-stream with a server that does NOT support `Accept-Ranges`
- [ ] 11.3 Test pause → background → resume flow across app kills using Xcode background task debugger
- [ ] 11.4 Test Live Activity on device (simulator does not support Dynamic Island)
- [ ] 11.5 Test SwiftData throttle: simulate 60 fps progress updates and confirm ≤1 write/second in Xcode Instruments (Core Data / SwiftData instrument)
- [ ] 11.6 Test disk-full scenario by filling available space and verifying the user-facing error appears
- [ ] 11.7 Test orphan temp file cleanup on launch after a simulated crash mid-download
- [ ] 11.8 Verify all UI surfaces meet WCAG AA contrast ratios in both light and dark mode
- [ ] 11.9 Profile memory usage during a multi-GB chunked download using Xcode Instruments (Allocations)
- [ ] 11.10 Verify App Store compliance: no private APIs, correct entitlements, all background modes declared
