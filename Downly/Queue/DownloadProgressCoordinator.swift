import Foundation
import SwiftData

/// Subscribes to ``DownloadEngine`` progress streams for a given download
/// and fans the updates out to:
///   1. ``PersistenceThrottle`` (SwiftData)     — task 10.2
///   2. ``LiveActivityManager``                  — task 10.2
///
/// Also handles completion and error notifications:
///   - task 10.3: completion → merge → status update → LiveActivity end
///   - task 10.4: error → status update → LiveActivity end
@MainActor
final class DownloadProgressCoordinator {

    private let throttle:       PersistenceThrottle
    private let liveActivity:   LiveActivityManager
    private let modelContext:   ModelContext

    init(
        throttle: PersistenceThrottle,
        liveActivity: LiveActivityManager = .shared,
        modelContext: ModelContext
    ) {
        self.throttle     = throttle
        self.liveActivity = liveActivity
        self.modelContext = modelContext
    }

    /// Observe a progress stream for the given download and forward updates.
    func observe(stream: DownloadEngine.ProgressStream, downloadID: UUID) {
        Task { [weak self] in
            guard let self else { return }
            for await progress in stream {
                await self.handleProgress(progress, downloadID: downloadID)
            }
        }
    }

    // MARK: - Private

    private func handleProgress(_ progress: DownloadProgress, downloadID: UUID) async {
        // Build the @MainActor save closure that PersistenceThrottle will call
        // back on the main thread. Capturing `modelContext` here is safe because
        // we're on @MainActor and the closure will always be invoked on @MainActor.
        let context = modelContext
        let saveClosure: @MainActor (UUID, Int64, Int64, DownloadStatus, String?, Int64, Int?) -> Void = {
            [weak self] id, downloaded, total, status, errorMsg, speed, eta in
            guard self != nil else { return }
            let descriptor = FetchDescriptor<DownloadItem>(
                predicate: #Predicate { $0.id == id }
            )
            guard let item = try? context.fetch(descriptor).first else { return }
            item.downloadedSize              = downloaded
            item.totalSize                   = total
            item.status                      = status
            item.errorMessage                = errorMsg
            item.speedBytesPerSecond         = speed
            item.estimatedSecondsRemaining   = eta
            item.updatedAt                   = Date()
            try? context.save()
        }

        // 1. Persist (throttled) — all SwiftData work runs on @MainActor via the closure
        await throttle.enqueue(
            id: downloadID,
            downloadedSize: progress.totalBytesWritten,
            totalSize: progress.totalBytesExpected,
            status: .running,
            speedBytesPerSecond: progress.speed,
            estimatedSecondsRemaining: progress.estimatedSecondsRemaining,
            save: saveClosure
        )

        // 2. Speed history — recorded every progress tick (throttled to 0.5 s by engine)
        let historyStore = SpeedHistoryStore.shared
        await MainActor.run {
            historyStore.history(for: downloadID).record(bytesPerSecond: progress.speed)
        }

        // 3. Live Activity update
        let state = DownloadAttributes.ContentState(
            progressPercent: progress.percent,
            speedBytesPerSecond: progress.speed,
            estimatedSecondsRemaining: progress.estimatedSecondsRemaining,
            statusRaw: DownloadStatus.running.rawValue
        )
        await liveActivity.updateActivity(id: downloadID, state: state)
    }

    /// Call when a download completes to update state and end Live Activity.
    func handleCompletion(downloadID: UUID) async {
        await liveActivity.endOnCompletion(id: downloadID)

        let context = modelContext
        let total = getItem(id: downloadID)?.totalSize ?? 0
        let saveClosure: @MainActor (UUID, Int64, Int64, DownloadStatus, String?, Int64, Int?) -> Void = {
            id, downloaded, totalSize, status, errorMsg, speed, eta in
            let descriptor = FetchDescriptor<DownloadItem>(
                predicate: #Predicate { $0.id == id }
            )
            guard let item = try? context.fetch(descriptor).first else { return }
            item.downloadedSize            = downloaded
            item.totalSize                 = totalSize
            item.status                    = status
            item.errorMessage              = errorMsg
            item.estimatedSecondsRemaining = nil
            item.updatedAt                 = Date()
            try? context.save()
        }
        await throttle.forceFlush(
            id: downloadID,
            downloadedSize: total,
            totalSize: total,
            status: .completed,
            save: saveClosure
        )
    }

    /// Call when a download permanently fails to update state and end Live Activity.
    func handleFailure(downloadID: UUID, message: String) async {
        await liveActivity.endOnFailure(id: downloadID)

        let context = modelContext
        let item = getItem(id: downloadID)
        let downloaded = item?.downloadedSize ?? 0
        let total      = item?.totalSize ?? 0
        let saveClosure: @MainActor (UUID, Int64, Int64, DownloadStatus, String?, Int64, Int?) -> Void = {
            id, dl, tot, status, errorMsg, speed, eta in
            let descriptor = FetchDescriptor<DownloadItem>(
                predicate: #Predicate { $0.id == id }
            )
            guard let itm = try? context.fetch(descriptor).first else { return }
            itm.downloadedSize            = dl
            itm.totalSize                 = tot
            itm.status                    = status
            itm.errorMessage              = errorMsg
            itm.estimatedSecondsRemaining = nil
            itm.updatedAt                 = Date()
            try? context.save()
        }
        await throttle.forceFlush(
            id: downloadID,
            downloadedSize: downloaded,
            totalSize: total,
            status: .error,
            errorMessage: message,
            save: saveClosure
        )
    }

    private func getItem(id: UUID) -> DownloadItem? {
        let descriptor = FetchDescriptor<DownloadItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
