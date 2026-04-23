import Foundation
import SwiftData

/// SwiftData model representing a single download item and all its metadata.
///
/// Raw file bytes are NEVER stored here — only paths, sizes, and state.
@Model
final class DownloadItem {

    // MARK: - Identity

    var id: UUID
    var url: String
    var fileName: String

    // MARK: - Size tracking

    /// Total file size in bytes as reported by the server (0 if unknown).
    var totalSize: Int64
    /// Bytes successfully downloaded and written to disk so far.
    var downloadedSize: Int64
    /// Current download speed in bytes per second (updated during active downloads).
    var speedBytesPerSecond: Int64
    /// Estimated seconds remaining until download completion (nil when unknown).
    var estimatedSecondsRemaining: Int?

    // MARK: - State

    /// Raw string backing for ``DownloadStatus``.
    var statusRaw: String

    /// Typed accessor for the download status.
    var status: DownloadStatus {
        get { DownloadStatus(rawValue: statusRaw) ?? .error }
        set { statusRaw = newValue.rawValue }
    }

    // MARK: - Resume support

    /// Serialised resumeData blob from URLSession, used to resume interrupted downloads.
    var resumeData: Data?

    // MARK: - Error

    var errorMessage: String?

    // MARK: - Chunking configuration

    /// Chunk size in bytes chosen by the user (default 4 MB).
    var chunkSize: Int

    // MARK: - Timestamps

    var createdAt: Date
    var updatedAt: Date

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade)
    var chunks: [ChunkRecord]

    // MARK: - Computed helpers

    var progressPercent: Double {
        guard totalSize > 0 else { return 0 }
        return min(Double(downloadedSize) / Double(totalSize) * 100, 100)
    }

    var remainingSize: Int64 {
        max(totalSize - downloadedSize, 0)
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        url: String,
        fileName: String,
        totalSize: Int64 = 0,
        downloadedSize: Int64 = 0,
        speedBytesPerSecond: Int64 = 0,
        estimatedSecondsRemaining: Int? = nil,
        status: DownloadStatus = .pending,
        resumeData: Data? = nil,
        errorMessage: String? = nil,
        chunkSize: Int = 4 * 1024 * 1024
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.totalSize = totalSize
        self.downloadedSize = downloadedSize
        self.speedBytesPerSecond = speedBytesPerSecond
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
        self.statusRaw = status.rawValue
        self.resumeData = resumeData
        self.errorMessage = errorMessage
        self.chunkSize = chunkSize
        self.createdAt = Date()
        self.updatedAt = Date()
        self.chunks = []
    }
}
