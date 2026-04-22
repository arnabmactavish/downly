import ActivityKit
import Foundation

/// Attributes that describe a Downly Live Activity.
///
/// Static fields (set at start, never change) go in ``DownloadAttributes``.
/// Mutable progress fields go in ``DownloadAttributes/ContentState``.
struct DownloadAttributes: ActivityAttributes {

    // MARK: - Static (identity)

    // DownloadStatus is defined in Models/DownloadStatus.swift (same module)

    /// Unique identifier of the download this Live Activity tracks.
    public let downloadID: UUID

    /// Display name of the file being downloaded.
    public let fileName: String

    // MARK: - ContentState (mutable, pushed as updates)

    public struct ContentState: Codable, Hashable {

        /// Download completion 0–100.
        var progressPercent: Double

        /// Current download speed in bytes per second.
        var speedBytesPerSecond: Int64

        /// Estimated seconds until completion (nil if unknown).
        var estimatedSecondsRemaining: Int?

        /// Current status of the download.
        var statusRaw: String

        var status: DownloadStatus {
            DownloadStatus(rawValue: statusRaw) ?? .running
        }

        // MARK: - Formatted helpers used by the widget UI

        var formattedSpeed: String {
            ByteCountFormatter.string(
                fromByteCount: speedBytesPerSecond,
                countStyle: .file
            ) + "/s"
        }

        var formattedETA: String {
            guard let secs = estimatedSecondsRemaining, secs > 0 else { return "--" }
            if secs < 60 { return "\(secs)s" }
            let m = secs / 60
            if m < 60 { return "\(m)m" }
            return "\(m / 60)h \(m % 60)m"
        }
    }
}
