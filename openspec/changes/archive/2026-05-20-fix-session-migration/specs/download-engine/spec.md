## MODIFIED Requirements

### Requirement: Error handling and retry
The system SHALL detect network errors and apply an exponential-backoff retry strategy up to 3 attempts before marking a download as failed. The system SHALL distinguish between migration-induced cancellations and genuine failures, suppressing error reporting for the former.

#### Scenario: Transient network error retry
- **WHEN** a download task fails with a transient error (e.g., `NSURLErrorNetworkConnectionLost`)
- **THEN** the engine SHALL wait 2^attempt seconds (2 s, 4 s, 8 s) before retrying, up to 3 times

#### Scenario: Permanent error
- **WHEN** a download fails after 3 retries or with a non-retryable error (e.g., 404 HTTP status)
- **THEN** the download MUST be marked with status `.error` and the error message displayed in the UI

#### Scenario: Migration-induced cancellation
- **WHEN** a download task fails with `NSURLErrorCancelled` and the download ID is in the engine's migrating set
- **THEN** the engine MUST NOT post `.downloadTaskDidFail`
- **AND** the engine MUST NOT increment the retry counter
- **AND** the engine MUST allow the migration flow to handle task re-creation on the background session
