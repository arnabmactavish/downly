## Why

iOS lacks a capable, native file downloader that supports multi-part downloads, background execution, and live progress tracking. Existing solutions rely on web views or third-party engines that don't take advantage of Apple's modern frameworks (SwiftData, ActivityKit, URLSession background transfers). Downly fills this gap by delivering an IDM-inspired downloading experience built entirely on native iOS APIs.

## What Changes

- **New app** — Downly, a standalone iOS file downloader application built from the ground up
- **Background downloading** — Uses `URLSessionConfiguration.background` so transfers survive app termination
- **Multi-part chunking** — Splits files into concurrent HTTP Range-based chunks for higher throughput
- **Pause / Resume** — Full pause/resume lifecycle using URLSession `resumeData`
- **Persistent state** — All download metadata and chunk relationships tracked in SwiftData (iOS 17+)
- **File assembly** — Temporary chunk files merged sequentially via `FileHandle` into the final output
- **Queue management** — `OperationQueue` controls concurrency (max 3 simultaneous downloads)
- **Live Activities** — Real-time progress shown on the Lock Screen / Dynamic Island via ActivityKit
- **Modern UI** — Liquid Glass design language: blur, transparency, floating navigation, per-item progress cards

## Capabilities

### New Capabilities

- `download-engine`: Core URLSession-based download engine with background session configuration, delegate-based progress tracking, pause/resume via resumeData, and error/retry handling
- `chunk-manager`: HTTP Range request chunking — HEAD request to detect server support, file splitting into configurable 1–5 MB parts, parallel concurrent chunk downloads with fallback to single-stream
- `file-assembly`: Disk I/O layer that writes chunk temp files (`file.part0`, `file.part1`, …), merges them sequentially using FileHandle, validates final file size, and cleans up temp files
- `download-queue`: OperationQueue-backed queue manager enforcing max concurrent downloads (3), tracking per-download state (pending / running / paused / completed / error)
- `persistence-layer`: SwiftData model layer storing download metadata (URL, filename, status, progress, chunk relationships); throttled writes (≤1 s / +1% progress delta) with no raw file data stored
- `live-activity`: ActivityKit integration that starts a Live Activity on download begin, pushes periodic progress updates (name, %, speed, ETA), and ends on completion or failure
- `download-ui`: Main screen with floating bottom navigation (All / Downloading / Paused / Done / Error), floating Edit/Settings buttons, Add Download FAB, URL-input modal with optional filename editing, and per-item progress cards showing name, size, downloaded, remaining, speed, and status

### Modified Capabilities

<!-- No existing capabilities — this is a new application -->

## Impact

- **New codebase** — No legacy code affected; all files are net-new
- **iOS 17+ required** — SwiftData and latest ActivityKit APIs
- **Frameworks added**: SwiftData, ActivityKit, URLSession (background), FileManager, OperationQueue
- **Entitlements**: Background Modes (fetch + processing), App Groups (for extension data sharing with Live Activities), NSNetworkingAttributeValue if needed
- **No third-party dependencies** — 100% native Apple frameworks
