## ADDED Requirements

### Requirement: SwiftData download model
The system SHALL define a `@Model` class `DownloadItem` in SwiftData that stores all metadata required to reconstruct a download across app launches.

#### Scenario: Minimum required fields
- **WHEN** a new download is created
- **THEN** the SwiftData model MUST include: `id` (UUID), `url` (String), `fileName` (String), `totalSize` (Int64), `downloadedSize` (Int64), `status` (DownloadStatus enum raw value), `resumeData` (Data?), `createdAt` (Date), `updatedAt` (Date)

#### Scenario: No raw file data stored
- **WHEN** file bytes are received
- **THEN** they MUST NOT be stored in SwiftData; only file paths and byte counts SHALL be persisted

### Requirement: Chunk relationship model
The system SHALL define a `@Model` class `ChunkRecord` related to `DownloadItem` that tracks each chunk's index, byte range, status, and local temp file path.

#### Scenario: Chunk record creation
- **WHEN** a chunked download is initialized
- **THEN** a `ChunkRecord` MUST be created for each chunk with: `index` (Int), `rangeStart` (Int64), `rangeEnd` (Int64), `status` (ChunkStatus), `tempFilePath` (String?), and a relationship back to its parent `DownloadItem`

#### Scenario: Chunk status persistence
- **WHEN** a chunk download completes
- **THEN** its `ChunkRecord.status` MUST be updated to `.completed` and `tempFilePath` set to the absolute path of the written temp file

### Requirement: Throttled progress writes
The system SHALL throttle SwiftData write frequency to avoid excessive I/O during high-frequency progress callbacks.

#### Scenario: Time-based throttle
- **WHEN** progress callbacks arrive more frequently than once per second
- **THEN** only one SwiftData write SHALL occur per second; intermediate values are buffered in memory

#### Scenario: Percentage-based throttle gate
- **WHEN** a progress update does not represent at least 1% change in download completion
- **THEN** the write MUST be skipped regardless of time elapsed, unless the download has just entered a new state

#### Scenario: State change bypass throttle
- **WHEN** a download transitions to a new status (e.g., `.running` → `.paused`)
- **THEN** a SwiftData write MUST occur immediately regardless of the throttle timer

### Requirement: Model version migration
The system SHALL use SwiftData's versioned model schema to manage future schema changes without data loss.

#### Scenario: First-launch schema
- **WHEN** the app is installed for the first time
- **THEN** SwiftData MUST create the schema at the current version (v1) automatically

#### Scenario: Upgrade migration
- **WHEN** the app is updated with a new schema version
- **THEN** SwiftData's migration plan MUST run without deleting existing download records
