import Foundation
import OSLog

/// Lightweight structured logging for the Downly download subsystem.
///
/// Every method writes to the `os.Logger` subsystem so messages are visible
/// in Console.app at runtime. In DEBUG builds, a plain `print()` is also
/// emitted so developers see output directly in the Xcode console without
/// needing to open Console.app.
///
/// In Release builds **no** `print()` or `NSLog()` calls are emitted.
enum DownlyLogger {

    private static let logger = Logger(
        subsystem: "com.axoman.downly",
        category: "downloads"
    )

    // MARK: - Lifecycle Events

    /// Log the start of a download task.
    nonisolated static func logStart(id: UUID, url: URL) {
        let msg = "[\(id.uuidString.prefix(8))] START → \(url.absoluteString)"
        logger.info("\(msg, privacy: .public)")
#if DEBUG
        print("[Downly] \(msg)")
#endif
    }

    /// Log a throttled progress update.
    nonisolated static func logProgress(
        id: UUID,
        bytesWritten: Int64,
        totalBytes: Int64,
        speed: Int64
    ) {
        let pct = totalBytes > 0
            ? String(format: "%.1f%%", Double(bytesWritten) / Double(totalBytes) * 100)
            : "?%"
        let speedStr = ByteCountFormatter.string(
            fromByteCount: speed,
            countStyle: .binary
        ) + "/s"
        let msg = "[\(id.uuidString.prefix(8))] PROGRESS \(pct) — \(bytesWritten)/\(totalBytes) bytes @ \(speedStr)"
        logger.debug("\(msg, privacy: .public)")
#if DEBUG
        print("[Downly] \(msg)")
#endif
    }

    /// Log a successful download completion.
    nonisolated static func logCompletion(id: UUID, path: String) {
        let msg = "[\(id.uuidString.prefix(8))] COMPLETED → \(path)"
        logger.info("\(msg, privacy: .public)")
#if DEBUG
        print("[Downly] \(msg)")
#endif
    }

    /// Log a download error (transient retry or permanent failure).
    nonisolated static func logError(id: UUID, error: Error) {
        let msg = "[\(id.uuidString.prefix(8))] ERROR — \(error.localizedDescription)"
        logger.error("\(msg, privacy: .public)")
#if DEBUG
        print("[Downly] \(msg)")
#endif
    }

    /// Log a file-staging or move error with a custom label.
    nonisolated static func logFileError(id: UUID, label: String, error: Error) {
        let msg = "[\(id.uuidString.prefix(8))] FILE-ERROR [\(label)] — \(error.localizedDescription)"
        logger.error("\(msg, privacy: .public)")
#if DEBUG
        print("[Downly] \(msg)")
#endif
    }
}
