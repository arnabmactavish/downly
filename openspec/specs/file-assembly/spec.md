## ADDED Requirements

### Requirement: Sequential chunk merging
The system SHALL merge downloaded chunk temp files into a single final output file in strict ascending chunk-index order using FileHandle streaming to maintain constant memory usage.

#### Scenario: Successful merge
- **WHEN** all chunks for a download have been written to disk as temp files
- **THEN** the assembly engine MUST open the output file for writing and sequentially append each chunk file using `FileHandle.write()`, then close all handles

#### Scenario: Chunk file missing at merge time
- **WHEN** one or more chunk temp files are not found on disk at merge time
- **THEN** the assembly MUST abort, mark the download as `.error`, and delete any partially merged output file

### Requirement: Final file size validation
After merging, the system SHALL verify that the final file size matches the expected content length from the HEAD response.

#### Scenario: Size matches
- **WHEN** the merged file size equals the expected content length
- **THEN** the download status SHALL be updated to `.completed`

#### Scenario: Size mismatch
- **WHEN** the merged file size does not match the expected content length
- **THEN** the final file MUST be deleted and the download marked as `.error` with message "File integrity check failed"

### Requirement: Temp file cleanup
The system SHALL delete all chunk temp files after a successful merge or after a download is cancelled or permanently failed.

#### Scenario: Post-merge cleanup
- **WHEN** the final file is successfully validated
- **THEN** all `<filename>.partN` temp files for that download MUST be deleted from the temporary directory

#### Scenario: App-launch stale temp file cleanup
- **WHEN** the app launches
- **THEN** the engine MUST scan the temp directory for orphaned `.partN` files whose associated download is no longer in a pending/active state and delete them

### Requirement: Disk space pre-check
Before starting a download, the system SHALL verify that sufficient free disk space exists for both the chunk temp files and the final assembled file.

#### Scenario: Insufficient disk space
- **WHEN** available free space is less than 110% of the expected file size (buffer for temp files)
- **THEN** the download MUST NOT start and the user SHALL be shown an error: "Not enough storage space"
