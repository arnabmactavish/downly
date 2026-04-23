## MODIFIED Requirements

### Requirement: Sequential chunk merging
The system SHALL merge downloaded chunk temp files into a single final output file in strict ascending chunk-index order using FileHandle streaming to maintain constant memory usage. Chunk temp files SHALL be read from the App Group container's `tmp/` subdirectory instead of `FileManager.default.temporaryDirectory`.

#### Scenario: Successful merge
- **WHEN** all chunks for a download have been written to disk as temp files in the App Group `tmp/` directory
- **THEN** the assembly engine MUST open the output file for writing and sequentially append each chunk file using `FileHandle.write()`, then close all handles

#### Scenario: Chunk file missing at merge time
- **WHEN** one or more chunk temp files are not found on disk at merge time
- **THEN** the assembly MUST abort, mark the download as `.error` with a detailed error message including the missing chunk index and expected path
- **AND** delete any partially merged output file

#### Scenario: Chunk file with zero bytes at merge time
- **WHEN** a chunk temp file exists but has zero bytes
- **THEN** the assembly MUST treat it as missing and abort with error message "Chunk N has 0 bytes — file may have been corrupted or evicted"

## ADDED Requirements

### Requirement: Chunk temp files stored in App Group container
Chunk temp files SHALL be written to the App Group container's `tmp/` subdirectory (`group.com.axoman.downly/tmp/`) instead of `FileManager.default.temporaryDirectory` to prevent iOS from purging them during backgrounding.

#### Scenario: Chunk writes to App Group tmp
- **WHEN** `ChunkCoordinator.downloadChunk` writes a completed chunk to disk
- **THEN** the temp file MUST be written to `containerURL(forSecurityApplicationGroupIdentifier:)/tmp/<downloadID>.part<index>`

#### Scenario: App Group tmp directory creation
- **WHEN** the first chunk is being written for a download
- **THEN** the `tmp/` subdirectory within the App Group container MUST be created if it does not already exist

### Requirement: Enriched merge error messages
All `FileAssemblyError` cases SHALL include actionable detail for debugging purposes.

#### Scenario: Chunk file missing error detail
- **WHEN** a chunk file is missing at merge time
- **THEN** the error message MUST include: chunk index, expected file path, and total chunk count (e.g., "Chunk 3 of 12 temp file not found at /path/to/file")

#### Scenario: Size mismatch error detail
- **WHEN** a size mismatch is detected
- **THEN** the error message MUST include both expected and actual byte counts (e.g., "File integrity check failed — expected 52428800 bytes, got 52428799 bytes")
