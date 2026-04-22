## ADDED Requirements

### Requirement: Stable temp file before notification
`DownloadEngine` SHALL copy the `URLSessionDownloadTask` temp file to a durable path inside `handleCompletion` before posting the `.downloadTaskDidFinish` notification, so that `DownloadQueueManager` can safely move the file from the `userInfo` URL at any point after receiving the notification.

#### Scenario: Temp file copied to stable location
- **WHEN** `urlSession(_:downloadTask:didFinishDownloadingTo:)` fires with a valid `location`
- **THEN** `DownloadEngine` SHALL copy that file to `FileManager.default.temporaryDirectory/<downloadID>.tmp` before the delegate method returns

#### Scenario: Notification carries stable URL
- **WHEN** `.downloadTaskDidFinish` notification is posted
- **THEN** the notification's `userInfo` SHALL contain key `"stableLocation"` with the copied `URL` (not the original system-managed `location`)

#### Scenario: Original tempLocation key removed
- **WHEN** `.downloadTaskDidFinish` notification is posted
- **THEN** the notification's `userInfo` SHALL NOT contain key `"tempLocation"` to prevent callers from accidentally relying on the invalidated URL

### Requirement: Queue manager consumes stable URL
`DownloadQueueManager.waitForSingleStreamCompletion` SHALL read `"stableLocation"` from the notification `userInfo` and delete the stable copy after a successful file move or on error.

#### Scenario: Successful single-stream download
- **WHEN** `.downloadTaskDidFinish` notification arrives with `"stableLocation"`
- **THEN** `DownloadQueueManager` SHALL move the file from `stableLocation` to the Documents directory and mark the download `.completed`

#### Scenario: File move failure — stable copy cleaned up
- **WHEN** `FileManager.moveItem` throws an error
- **THEN** `DownloadQueueManager` SHALL attempt to delete the stable copy and mark the download `.error`

#### Scenario: Copy failure in engine — fallback
- **WHEN** `FileManager.copyItem` throws inside `DownloadEngine.handleCompletion`
- **THEN** `DownloadEngine` SHALL post `.downloadTaskDidFail` instead of `.downloadTaskDidFinish`, so `DownloadQueueManager` marks the download `.error`
