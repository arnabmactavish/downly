import Foundation
import SwiftData

/// Buffers high-frequency progress updates and commits them to SwiftData
/// at most once per second **or** when progress advances by ≥ 1%.
///
/// In-memory state is updated synchronously for live UI rendering;
/// persistence writes are coalesced to avoid I/O thrashing.
///
/// All SwiftData operations are dispatched back to the `@MainActor` via
/// the `save` closure so that the `ModelContext` is always accessed on the
/// queue it was created on. This eliminates the "Unbinding from the main
/// queue" SwiftData warning.
actor PersistenceThrottle {

    // MARK: - Configuration

    private let minWriteInterval: TimeInterval
    private let minProgressGate: Double

    // MARK: - Pending state

    private struct PendingUpdate {
        let downloadedSize: Int64
        let totalSize: Int64
        let status: DownloadStatus
        let errorMessage: String?
        let speedBytesPerSecond: Int64
    }

    private var pendingUpdates: [UUID: PendingUpdate] = [:]
    private var lastWriteTimes:  [UUID: Date]          = [:]
    private var lastPercentages: [UUID: Double]        = [:]

    // MARK: - Init

    init(
        minWriteInterval: TimeInterval = 1.0,
        minProgressGate: Double = 1.0
    ) {
        self.minWriteInterval = minWriteInterval
        self.minProgressGate  = minProgressGate
    }

    // MARK: - Public API

    /// Buffer a progress update. Flushes immediately if the throttle window allows it.
    ///
    /// - Parameters:
    ///   - save: A `@MainActor` closure that applies a field-update block to
    ///           SwiftData and calls `context.save()`. Running the mutation on
    ///           the main actor keeps the `ModelContext` on its home thread.
    func enqueue(
        id: UUID,
        downloadedSize: Int64,
        totalSize: Int64,
        status: DownloadStatus,
        errorMessage: String? = nil,
        speedBytesPerSecond: Int64 = 0,
        save: @escaping @MainActor (UUID, Int64, Int64, DownloadStatus, String?, Int64) -> Void
    ) async {
        let now = Date()
        let lastWrite  = lastWriteTimes[id]
        let lastPct    = lastPercentages[id] ?? -1

        let currentPct = totalSize > 0
            ? Double(downloadedSize) / Double(totalSize) * 100
            : 0

        let timePassed = lastWrite.map { now.timeIntervalSince($0) >= minWriteInterval } ?? true
        let pctChanged = (currentPct - lastPct) >= minProgressGate

        if timePassed || pctChanged {
            await flush(
                id: id,
                downloadedSize: downloadedSize,
                totalSize: totalSize,
                status: status,
                errorMessage: errorMessage,
                speedBytesPerSecond: speedBytesPerSecond,
                save: save,
                now: now,
                currentPct: currentPct
            )
        } else {
            pendingUpdates[id] = PendingUpdate(
                downloadedSize: downloadedSize,
                totalSize: totalSize,
                status: status,
                errorMessage: errorMessage,
                speedBytesPerSecond: speedBytesPerSecond
            )
        }
    }

    /// Force an immediate write for a state transition (pause, complete, error).
    func forceFlush(
        id: UUID,
        downloadedSize: Int64,
        totalSize: Int64,
        status: DownloadStatus,
        errorMessage: String? = nil,
        speedBytesPerSecond: Int64 = 0,
        save: @escaping @MainActor (UUID, Int64, Int64, DownloadStatus, String?, Int64) -> Void
    ) async {
        let currentPct = totalSize > 0
            ? Double(downloadedSize) / Double(totalSize) * 100
            : 0
        await flush(
            id: id,
            downloadedSize: downloadedSize,
            totalSize: totalSize,
            status: status,
            errorMessage: errorMessage,
            speedBytesPerSecond: speedBytesPerSecond,
            save: save,
            now: Date(),
            currentPct: currentPct
        )
    }

    // MARK: - Private

    private func flush(
        id: UUID,
        downloadedSize: Int64,
        totalSize: Int64,
        status: DownloadStatus,
        errorMessage: String?,
        speedBytesPerSecond: Int64,
        save: @escaping @MainActor (UUID, Int64, Int64, DownloadStatus, String?, Int64) -> Void,
        now: Date,
        currentPct: Double
    ) async {
        // Dispatch the actual SwiftData write back to @MainActor so the
        // ModelContext is always accessed on the queue where it was created.
        await MainActor.run {
            save(id, downloadedSize, totalSize, status, errorMessage, speedBytesPerSecond)
        }

        lastWriteTimes[id]  = now
        lastPercentages[id] = currentPct
        pendingUpdates.removeValue(forKey: id)
    }
}
