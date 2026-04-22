## ADDED Requirements

### Requirement: Server range-support detection
Before initiating a chunked download, the system SHALL send an HTTP HEAD request to determine whether the server supports byte-range requests and the total file size.

#### Scenario: Server supports ranges
- **WHEN** the HEAD response contains `Accept-Ranges: bytes` and a valid `Content-Length`
- **THEN** the engine SHALL proceed with chunked download using the reported content length to compute byte ranges

#### Scenario: Server does not support ranges
- **WHEN** the HEAD response is missing `Accept-Ranges: bytes` or Content-Length is absent
- **THEN** the engine SHALL immediately fall back to a single-connection download without chunking

### Requirement: Configurable chunk size
The system SHALL split files into chunks of a user-configurable size (default: 4 MB; options: 1 MB, 4 MB, 8 MB) computed from the total file size.

#### Scenario: Even division
- **WHEN** the file size is evenly divisible by the chunk size
- **THEN** each chunk SHALL cover exactly chunkSize bytes

#### Scenario: Uneven division (last chunk)
- **WHEN** the file size is not evenly divisible by chunk size
- **THEN** the last chunk SHALL cover the remaining bytes (i.e., fileSize mod chunkSize)

### Requirement: Concurrent chunk downloads
The system SHALL issue parallel HTTP Range requests for each chunk, limited to a maximum of 6 concurrent chunk tasks per single download.

#### Scenario: Max-concurrency enforcement
- **WHEN** more than 6 chunks are pending for one download
- **THEN** chunks beyond the concurrency limit MUST be queued and started only as prior chunks complete

#### Scenario: Chunk byte range header
- **WHEN** a chunk download task is created
- **THEN** the task MUST include the HTTP header `Range: bytes=<start>-<end>` corresponding to that chunk's byte range

#### Scenario: Chunk partial response validation
- **WHEN** the server returns HTTP 206 Partial Content for a chunk request
- **THEN** the chunk is considered valid and its temp file MUST be written to disk

#### Scenario: Chunk receives wrong status
- **WHEN** a chunk request receives any response other than 206 or 200
- **THEN** the chunk MUST be retried (up to 3 times) and the download marked as error if all retries fail

### Requirement: Chunk fallback on failure
The system SHALL fall back to single-stream download if chunking fails mid-download and partial data cannot be reconciled.

#### Scenario: Irrecoverable chunk set
- **WHEN** two or more chunks fail permanently
- **THEN** the engine MUST cancel remaining chunks, discard temp files, and restart the download as a single-stream task
