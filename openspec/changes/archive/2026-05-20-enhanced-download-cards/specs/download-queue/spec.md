## ADDED Requirements

### Requirement: Update download URL API
`DownloadQueueManager` SHALL expose an `updateURL(id:newURL:)` async throws method that validates the new URL and updates the download record.

#### Scenario: Successful URL update
- **WHEN** `updateURL(id: downloadID, newURL: validURL)` is called for a download in `.paused` or `.error` state and the HEAD request confirms range support and compatible content length
- **THEN** the `DownloadItem.url` SHALL be updated, `resumeData` SHALL be cleared, incomplete chunk records SHALL have their status reset, and the download status SHALL be set to `.paused`

#### Scenario: URL update on running download
- **WHEN** `updateURL` is called for a download in `.running` state
- **THEN** the method SHALL throw `DownloadQueueError.downloadMustBePaused`

#### Scenario: URL update with incompatible server
- **WHEN** `updateURL` is called and the HEAD request fails or returns no range support
- **THEN** the method SHALL throw `DownloadQueueError.urlNotCompatible(reason:)` with a descriptive reason string

#### Scenario: URL update with size mismatch but user accepts fresh start
- **WHEN** the HEAD response shows `Content-Length` < current `downloadedSize` and the caller passes `resetProgress: true`
- **THEN** the `DownloadItem` SHALL be updated with the new URL, `downloadedSize` reset to 0, all chunk records deleted, and status set to `.pending`
