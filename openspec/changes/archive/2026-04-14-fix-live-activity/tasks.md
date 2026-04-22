## 1. LiveActivityManager — Preference Guard

- [x] 1.1 Add `UserDefaults.standard.bool(forKey: "liveActivitiesEnabled")` check at the top of `startActivity(for:)`, returning early if `false` (treat missing key as `true`)
- [x] 1.2 Add guard to skip `startActivity` if an activity for the same `item.id` already exists in the `activities` dictionary (prevents duplicates on resume)

## 2. DownloadQueueManager — Call startActivity

- [x] 2.1 In `executeDownload`, after the item is marked `.running` and before `engine.startDownload`, call `await LiveActivityManager.shared.startActivity(for: item)` — requires fetching the current `DownloadItem` from the model context at that point to pass to `startActivity`
- [x] 2.2 In the chunked download path (`executeDownload`), call `await LiveActivityManager.shared.startActivity(for: item)` in the same `MainActor.run` block that sets `item.status = .running`, before `ChunkCoordinator.downloadAll`

## 3. DownloadQueueManager — Chunked Live Activity Progress

- [x] 3.1 Inside the chunk-completion callback closure (the trailing closure passed to `coordinator.downloadAll`), after updating `item.downloadedSize`, call `await LiveActivityManager.shared.updateActivity(id: id, state: ...)` synthesising a `DownloadAttributes.ContentState` with `progressPercent = item.progressPercent`, `speedBytesPerSecond = 0`, `estimatedSecondsRemaining = nil`, `statusRaw = DownloadStatus.running.rawValue`

## 4. SettingsView — Live Activity Toggle

- [x] 4.1 Add `@AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled = true` to `SettingsView`
- [x] 4.2 Add a new `settingsCard(title: "Live Activities")` section containing a `Toggle` bound to `$liveActivitiesEnabled` with label text `"Show progress on Lock Screen & Dynamic Island"` and a caption: `"Displays download progress on your Lock Screen and Dynamic Island. May increase battery usage during large downloads."`
- [x] 4.3 Position the new card between the "Network" section and the "Storage" section for logical grouping

## 5. Verification

- [x] 5.1 Build the app target in Xcode and confirm zero errors/warnings introduced by these changes
- [x] 5.2 Build the widget extension target and confirm it still compiles cleanly (no drift in `DownloadAttributes`)
- [ ] 5.3 Run on a physical device (or Simulator with iOS 16.2+): start a download and verify the Live Activity banner appears on the Lock Screen / Dynamic Island
- [ ] 5.4 Verify the progress bar and percentage update during an active download
- [ ] 5.5 Verify the Live Activity dismisses ~5 seconds after download completion
- [ ] 5.6 Toggle Live Activities off in Settings, start a download, confirm no Live Activity appears
- [ ] 5.7 Toggle Live Activities back on, start a download, confirm Live Activity reappears
