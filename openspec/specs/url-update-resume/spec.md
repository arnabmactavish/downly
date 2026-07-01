## Requirements

### Requirement: User can update download URL
The system SHALL allow users to provide a new URL for a download in `.error`, `.paused`, or `.interrupted` state, enabling resumption from existing byte progress.

#### Scenario: Update URL via context menu
- **WHEN** user selects "Update URL" from long press context menu on a paused/errored download
- **THEN** a sheet SHALL present with a text field pre-populated from clipboard (if URL), allowing the user to enter a new URL

#### Scenario: Update URL via detail sheet
- **WHEN** user taps "Update URL" button in the download detail bottom sheet for a paused/errored download
- **THEN** the same URL update sheet SHALL present

### Requirement: Server compatibility validation before URL update
The system SHALL validate the new URL via HEAD request before accepting the update.

#### Scenario: Compatible server response
- **WHEN** user submits a new URL and the HEAD response returns `Accept-Ranges: bytes` and `Content-Length` >= current `downloadedSize`
- **THEN** the system SHALL update `DownloadItem.url` to the new URL, clear `resumeData`, set status to `.paused`, and show a success confirmation

#### Scenario: Server does not support range requests
- **WHEN** user submits a new URL and the HEAD response does not include `Accept-Ranges: bytes`
- **THEN** the system SHALL show an alert explaining that resume is not possible and offer "Start Fresh" (reset progress to 0) or "Cancel"

#### Scenario: Content-Length mismatch
- **WHEN** user submits a new URL and the HEAD response `Content-Length` is less than current `downloadedSize`
- **THEN** the system SHALL show an alert explaining the size mismatch and offer "Start Fresh" (reset progress to 0) or "Cancel"

#### Scenario: HEAD request fails
- **WHEN** the HEAD request to the new URL fails (network error, 404, etc.)
- **THEN** the system SHALL show an error alert with the failure reason and keep the original URL unchanged

### Requirement: Resume from byte offset with new URL
The system SHALL resume downloads from the existing byte offset using HTTP Range headers when a URL is updated.

#### Scenario: Successful resume after URL update
- **WHEN** user resumes a download whose URL was updated and `downloadedSize` > 0
- **THEN** the download engine SHALL send a `Range: bytes=<downloadedSize>-` header and append received data to existing progress

#### Scenario: Chunked download URL update
- **WHEN** a download with active chunk records has its URL updated
- **THEN** incomplete chunks SHALL be reset to their range start positions and the chunk coordinator SHALL use the new URL for all subsequent chunk requests

### Requirement: Queue manager updateURL API
`DownloadQueueManager` SHALL expose an `updateURL(id:newURL:)` async method that performs validation and URL replacement.

#### Scenario: Successful URL update via queue manager
- **WHEN** `updateURL(id: downloadID, newURL: "https://new.example.com/file.zip")` is called with a valid, compatible URL
- **THEN** the `DownloadItem` record SHALL be updated in SwiftData with the new URL and status set to `.paused`

#### Scenario: URL update rejected for running download
- **WHEN** `updateURL` is called for a download in `.running` state
- **THEN** the method SHALL throw an error indicating the download must be paused first
