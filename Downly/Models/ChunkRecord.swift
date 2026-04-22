import Foundation
import SwiftData

/// SwiftData model tracking a single byte-range chunk of a parent download.
///
/// Each ``ChunkRecord`` maps to one temporary file on disk (`fileName.partN`).
@Model
final class ChunkRecord {

    // MARK: - Identity

    /// Zero-based position of this chunk in the final assembled file.
    var index: Int

    // MARK: - Byte range

    var rangeStart: Int64
    var rangeEnd: Int64

    // MARK: - State

    var statusRaw: String

    var status: ChunkStatus {
        get { ChunkStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    // MARK: - Disk location

    /// Absolute path to the temporary `.partN` file, set once the chunk finishes downloading.
    var tempFilePath: String?

    // MARK: - Retry tracking

    var retryCount: Int

    // MARK: - Relationship

    var download: DownloadItem?

    // MARK: - Computed

    var byteCount: Int64 { rangeEnd - rangeStart + 1 }

    // MARK: - Init

    init(
        index: Int,
        rangeStart: Int64,
        rangeEnd: Int64,
        status: ChunkStatus = .pending,
        tempFilePath: String? = nil,
        retryCount: Int = 0
    ) {
        self.index = index
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.statusRaw = status.rawValue
        self.tempFilePath = tempFilePath
        self.retryCount = retryCount
    }
}
