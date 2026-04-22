import Foundation
import Combine
import SwiftData

/// Manages the download queue: enqueues, pauses, resumes, cancels,
/// and restores downloads across app launches.
///
/// Uses an `OperationQueue` limited to 3 concurrent downloads at the
/// download level. Each operation internally uses ``ChunkCoordinator``
/// for up to 6 concurrent chunk tasks.
@MainActor
final class DownloadQueueManager: ObservableObject {

    // MARK: - Dependencies

    private let engine:          DownloadEngine
    private let chunkManager:    ChunkManager
    private let assemblyEngine:  FileAssemblyEngine
    private let diskChecker:     DiskSpaceChecker
    private let modelContext:    ModelContext

    // MARK: - Queue

    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.downly.download-queue"
        q.maxConcurrentOperationCount = 3
        return q
    }()

    /// Map from download ID → its live Operation (if active).
    private var operations: [UUID: DownloadOperation] = [:]

    // MARK: - Init

    init(
        engine: DownloadEngine = .shared,
        chunkManager: ChunkManager = .init(),
        assemblyEngine: FileAssemblyEngine = .init(),
        diskChecker: DiskSpaceChecker = .init(),
        modelContext: ModelContext
    ) {
        self.engine         = engine
        self.chunkManager   = chunkManager
        self.assemblyEngine = assemblyEngine
        self.diskChecker    = diskChecker
        self.modelContext   = modelContext
    }

    // MARK: - Public API

    /// Add a new download to the queue.
    func addDownload(url: String, fileName: String, chunkSize: Int = 4 * 1024 * 1024) throws {
        guard let downloadURL = URL(string: url) else { return }

        // Disk pre-check using a conservative 0 estimate (actual size found later via HEAD)
        // Full pre-check is performed inside the operation once totalSize is known.

        let item = DownloadItem(
            url: url,
            fileName: fileName,
            chunkSize: chunkSize
        )
        modelContext.insert(item)
        try modelContext.save()

        enqueue(item: item, downloadURL: downloadURL)
    }

    /// Pause an active download.
    func pauseDownload(id: UUID) async {
        guard let op = operations[id],
              let item = fetchItem(id: id),
              item.status.canTransition(to: .paused)
        else { return }

        // Pause the URLSession task and persist resumeData
        await engine.pauseDownload(id: id) { [weak self] resumeData in
            Task { @MainActor [weak self] in
                guard let self, let item = self.fetchItem(id: id) else { return }
                item.resumeData = resumeData
                item.status     = .paused
                item.updatedAt  = Date()
                try? self.modelContext.save()
            }
        }

        op.cancel()
        operations.removeValue(forKey: id)
    }

    /// Resume a paused or interrupted download.
    func resumeDownload(id: UUID) {
        guard let item = fetchItem(id: id),
              item.status.canTransition(to: .running),
              let downloadURL = URL(string: item.url)
        else { return }

        item.status    = .running
        item.updatedAt = Date()
        try? modelContext.save()

        enqueue(item: item, downloadURL: downloadURL)
    }

    /// Cancel a download and clean up all associated resources.
    func cancelDownload(id: UUID) {
        operations[id]?.cancel()
        operations.removeValue(forKey: id)

        Task { await engine.cancelDownload(id: id) }

        // Clean up temp files
        if let item = fetchItem(id: id) {
            assemblyEngine.deleteChunkFiles(for: item.chunks)
            modelContext.delete(item)
            try? modelContext.save()
        }
    }

    /// Re-queue any `.pending` or `.interrupted` downloads found in SwiftData.
    /// Call this once at app launch.
    func restoreQueueOnLaunch() {
        let descriptor = FetchDescriptor<DownloadItem>(
            predicate: #Predicate { $0.statusRaw == "pending" || $0.statusRaw == "interrupted" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let items = try? modelContext.fetch(descriptor) else { return }
        for item in items {
            guard let url = URL(string: item.url) else { continue }
            enqueue(item: item, downloadURL: url)
        }
    }

    // MARK: - State machine validation

    private func transition(item: DownloadItem, to newStatus: DownloadStatus) throws {
        guard item.status.canTransition(to: newStatus) else {
            throw DownloadOperationError.invalidStateTransition(
                from: item.status, to: newStatus
            )
        }
        item.status    = newStatus
        item.updatedAt = Date()
        try modelContext.save()
    }

    // MARK: - Private

    private func enqueue(item: DownloadItem, downloadURL: URL) {
        let id          = item.id
        let chunkSize   = item.chunkSize
        let fileName    = item.fileName
        let resumeData  = item.resumeData
        let context     = modelContext

        let op = DownloadOperation(downloadID: id) { [weak self] in
            guard let self else { return }
            await self.executeDownload(
                id: id,
                url: downloadURL,
                fileName: fileName,
                chunkSize: chunkSize,
                resumeData: resumeData,
                context: context
            )
        }
        operations[id] = op
        queue.addOperation(op)
    }

    private func executeDownload(
        id: UUID,
        url: URL,
        fileName: String,
        chunkSize: Int,
        resumeData: Data?,
        context: ModelContext
    ) async {
        // Update status to running, then start Live Activity immediately so
        // the first progress update lands into an existing activity handle.
        await MainActor.run {
            guard let item = fetchItem(id: id) else { return }
            item.status    = .running
            item.updatedAt = Date()
            try? modelContext.save()
        }
        // Start Live Activity using captured primitives (safe across isolation).
        // Called after status update so the item state is consistent.
        await LiveActivityManager.shared.startActivity(id: id, fileName: fileName)

        do {
            // 1. Analyse server
            let capability = try await chunkManager.analyzeServer(url: url)

            // Resolve the best available filename:
            //   1. Server Content-Disposition (strongest signal)
            //   2. User-supplied name from the sheet
            //   3. URL last path component
            //   4. "download" as ultimate fallback
            // If the chosen name has no extension, try to infer one from Content-Type.
            let resolvedFileName: String = {
                var name: String
                if let serverName = capability.suggestedFileName, !serverName.isEmpty {
                    name = serverName
                } else if !fileName.isEmpty {
                    name = fileName
                } else {
                    let lastComp = url.lastPathComponent
                    name = lastComp.isEmpty ? "download" : lastComp
                }

                // If no extension, try to append one from Content-Type
                if URL(fileURLWithPath: name).pathExtension.isEmpty,
                   let mime = capability.contentType,
                   let ext = ChunkManager.inferExtension(from: mime) {
                    name = name + "." + ext
                }
                return name
            }()

            await MainActor.run {
                guard let item = fetchItem(id: id) else { return }
                if let size = capability.contentLength {
                    item.totalSize = size
                }
                // Persist the resolved filename so the UI shows the correct name.
                item.fileName  = resolvedFileName
                try? modelContext.save()
            }

            // 2. Disk space check
            if let size = capability.contentLength {
                guard diskChecker.hasSufficientSpace(forBytes: size) else {
                    await markError(id: id, message: "Not enough storage space")
                    return
                }
            }

            let tempDir = FileManager.default.temporaryDirectory

            // 3. Chunked or single-stream download
            if capability.supportsRanges,
               let totalSize = capability.contentLength,
               totalSize > Int64(chunkSize) {

                let ranges = chunkManager.splitIntoChunks(
                    totalSize: totalSize,
                    chunkSize: chunkSize
                )

                // Create ChunkRecords
                await MainActor.run {
                    guard let item = fetchItem(id: id) else { return }
                    for range in ranges {
                        let chunk = ChunkRecord(
                            index: range.index,
                            rangeStart: range.start,
                            rangeEnd: range.end
                        )
                        item.chunks.append(chunk)
                        context.insert(chunk)
                    }
                    try? context.save()
                }

                let coordinator = ChunkCoordinator()
                let result = await coordinator.downloadAll(
                    downloadID: id,
                    url: url,
                    chunks: ranges,
                    tempDir: tempDir
                ) { index, tempPath in
                    // Capture snapshot values for Live Activity update before
                    // leaving @MainActor — SwiftData objects must not escape.
                    let progressSnapshot: (percent: Double, total: Int64) = await MainActor.run {
                        guard let item = self.fetchItem(id: id),
                              let chunk = item.chunks.first(where: { $0.index == index })
                        else { return (0, 0) }
                        chunk.status       = .completed
                        chunk.tempFilePath = tempPath.path
                        item.downloadedSize += chunk.byteCount
                        item.updatedAt = Date()
                        try? context.save()
                        return (item.progressPercent, item.totalSize)
                    }
                    // Push Live Activity update for the chunked path.
                    // Speed is unknown per-chunk; ETA is omitted.
                    let chunkState = DownloadAttributes.ContentState(
                        progressPercent: progressSnapshot.percent,
                        speedBytesPerSecond: 0,
                        estimatedSecondsRemaining: nil,
                        statusRaw: DownloadStatus.running.rawValue
                    )
                    await LiveActivityManager.shared.updateActivity(id: id, state: chunkState)
                }

                switch result {
                case .success:
                    // 4. Merge
                    let outputURL = documentsURL(fileName: resolvedFileName)
                    guard let item = await MainActor.run(body: { fetchItem(id: id) }) else { return }
                    try await assemblyEngine.merge(
                        chunks: item.chunks,
                        into: outputURL,
                        expectedSize: capability.contentLength ?? 0
                    )
                    await markCompleted(id: id)

                case .fallbackToSingleStream:
                    // Clean up and retry as single stream
                    await MainActor.run {
                        if let item = fetchItem(id: id) {
                            assemblyEngine.deleteChunkFiles(for: item.chunks)
                            for chunk in item.chunks {
                                context.delete(chunk)
                            }
                            try? context.save()
                        }
                    }
                    // ── Register observer BEFORE starting download to avoid race ──
                    let fallbackObserver = makeCompletionStream(for: id)
                    let fallbackStream = await engine.startDownload(id: id, url: url)
                    let fallbackCoordinator = await MainActor.run {
                        DownloadProgressCoordinator(
                            throttle: PersistenceThrottle(),
                            modelContext: modelContext
                        )
                    }
                    await MainActor.run {
                        fallbackCoordinator.observe(stream: fallbackStream, downloadID: id)
                    }
                    await waitForSingleStreamCompletion(
                        id: id,
                        fileName: resolvedFileName,
                        observer: fallbackObserver
                    )
                }

            } else {
                // Single-stream download.
                // ── Register observer BEFORE starting download to avoid race ──
                // If the file is small/fast, handleCompletion fires the
                // downloadTaskDidFinish notification almost immediately after
                // startDownload returns. The old code registered the
                // NotificationCenter listener AFTER startDownload, so the
                // notification was silently dropped. We pre-register here.
                let completionObserver = makeCompletionStream(for: id)
                let progressStream = await engine.startDownload(
                    id: id,
                    url: url,
                    resumeData: resumeData
                )
                // Wire progress so UI sees bytes written, total size, and speed.
                let progressCoordinator = await MainActor.run {
                    DownloadProgressCoordinator(
                        throttle: PersistenceThrottle(),
                        modelContext: modelContext
                    )
                }
                await MainActor.run {
                    progressCoordinator.observe(stream: progressStream, downloadID: id)
                }
                await waitForSingleStreamCompletion(
                    id: id,
                    fileName: resolvedFileName,
                    observer: completionObserver
                )
            }

        } catch {
            await markError(id: id, message: error.localizedDescription)
        }
    }

    /// Builds an `AsyncStream` that delivers exactly one `DownloadOutcome`.
    ///
    /// **Must be called BEFORE `engine.startDownload()`.** The stream's
    /// internal `NotificationCenter` observer is registered synchronously here,
    /// so no notification fired by `handleCompletion` can be missed even if
    /// the download completes before the caller enters the `for await` loop.
    private enum DownloadOutcome {
        case success(URL)
        case failure(String)
    }

    private func makeCompletionStream(
        for downloadID: UUID
    ) -> AsyncStream<DownloadOutcome> {
        let nc = NotificationCenter.default
        return AsyncStream { continuation in
            var successToken: NSObjectProtocol?
            var failureToken: NSObjectProtocol?

            successToken = nc.addObserver(
                forName: .downloadTaskDidFinish,
                object: nil,
                queue: nil
            ) { notification in
                guard let nID = notification.userInfo?["downloadID"] as? UUID,
                      nID == downloadID
                else { return }
                if let url = notification.userInfo?["stableLocation"] as? URL {
                    continuation.yield(.success(url))
                }
                continuation.finish()
                if let t = successToken { nc.removeObserver(t) }
                if let t = failureToken { nc.removeObserver(t) }
            }

            failureToken = nc.addObserver(
                forName: .downloadTaskDidFail,
                object: nil,
                queue: nil
            ) { notification in
                guard let nID = notification.userInfo?["downloadID"] as? UUID,
                      nID == downloadID
                else { return }
                let message = (notification.userInfo?["error"] as? Error)?.localizedDescription
                    ?? "Download failed"
                continuation.yield(.failure(message))
                continuation.finish()
                if let t = successToken { nc.removeObserver(t) }
                if let t = failureToken { nc.removeObserver(t) }
            }

            continuation.onTermination = { _ in
                if let t = successToken { nc.removeObserver(t) }
                if let t = failureToken { nc.removeObserver(t) }
            }
        }
    }

    private func waitForSingleStreamCompletion(
        id: UUID,
        fileName: String,
        observer: AsyncStream<DownloadOutcome>
    ) async {
        for await result in observer {
            switch result {
            case .success(let stableLoc):
                let destURL = documentsURL(fileName: fileName)
                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: stableLoc, to: destURL)
                    DownlyLogger.logCompletion(id: id, path: destURL.path)
                    await markCompleted(id: id)
                } catch {
                    try? FileManager.default.removeItem(at: stableLoc)
                    await markError(id: id, message: error.localizedDescription)
                }

            case .failure(let message):
                await markError(id: id, message: message)
            }
        }
    }

    @MainActor
    private func markCompleted(id: UUID) {
        guard let item = fetchItem(id: id) else { return }
        item.status    = .completed
        item.updatedAt = Date()
        try? modelContext.save()
        operations.removeValue(forKey: id)

        // Push a final 100% update then end the Live Activity so the banner
        // briefly shows "Done" before dismissing. Must be done in a Task because
        // LiveActivityManager is an actor and this function is sync @MainActor.
        Task {
            let finalState = DownloadAttributes.ContentState(
                progressPercent: 100,
                speedBytesPerSecond: 0,
                estimatedSecondsRemaining: 0,
                statusRaw: DownloadStatus.completed.rawValue
            )
            // bypassThrottle: true — this final push must never be dropped
            // by the 2-second window, regardless of when the last update fired.
            await LiveActivityManager.shared.updateActivity(
                id: id,
                state: finalState,
                bypassThrottle: true
            )
            await LiveActivityManager.shared.endOnCompletion(id: id)
        }

        NotificationCenter.default.post(
            name: .downloadDidComplete,
            object: nil,
            userInfo: ["downloadID": id]
        )
    }

    @MainActor
    private func markError(id: UUID, message: String) {
        guard let item = fetchItem(id: id) else { return }
        item.status       = .error
        item.errorMessage = message
        item.updatedAt    = Date()
        try? modelContext.save()
        operations.removeValue(forKey: id)

        // End the Live Activity immediately on failure.
        Task {
            await LiveActivityManager.shared.endOnFailure(id: id)
        }

        NotificationCenter.default.post(
            name: .downloadDidFail,
            object: nil,
            userInfo: ["downloadID": id, "message": message]
        )
    }

    @MainActor
    private func fetchItem(id: UUID) -> DownloadItem? {
        let descriptor = FetchDescriptor<DownloadItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// Returns the final destination URL for a completed download.
    ///
    /// `UIFileSharingEnabled` (and `LSSupportsOpeningDocumentsInPlace`) expose
    /// the **app's own sandbox `Documents/`** directory to the iOS Files app
    /// (On My iPhone → Downly). The App Group container's `Documents/` subfolder
    /// is NOT exposed by those keys — that requires a FileProvider extension.
    ///
    /// Therefore we save directly into the sandbox Documents directory, not
    /// the App Group container.
    nonisolated private func documentsURL(fileName: String) -> URL {
        let fm = FileManager.default
        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Directory is guaranteed to exist on iOS, but createDirectory is
        // harmless if already present.
        try? fm.createDirectory(at: docsDir, withIntermediateDirectories: true)
        return docsDir.appendingPathComponent(fileName)
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let downloadDidComplete = Notification.Name("com.downly.downloadDidComplete")
    static let downloadDidFail     = Notification.Name("com.downly.downloadDidFail")
}
