import Foundation

/// Coordinates parallel chunk downloads for a single file, with retry
/// and fallback logic.
///
/// Up to ``maxConcurrentChunks`` chunk tasks run simultaneously.
/// If 2 or more chunks fail permanently the coordinator signals
/// the caller to fall back to a single-stream download.
actor ChunkCoordinator {

    // MARK: - Configuration

    private let maxConcurrentChunks = 6
    /// Dedicated ephemeral session for chunk requests, kept separate from
    /// the background URLSession in DownloadEngine to avoid connection conflicts.
    private let session: URLSession = URLSession(configuration: .ephemeral)
    private let maxChunkRetries     = 3

    // MARK: - Types

    enum CoordinatorResult {
        /// All chunks downloaded successfully. `tempPaths[i]` is the path
        /// for chunk at `index == i`.
        case success(tempPaths: [Int: URL])
        /// Too many chunks failed — caller should restart as single-stream.
        case fallbackToSingleStream
    }

    private struct ChunkTask {
        let range: ChunkRange
        var retryCount: Int = 0
        var tempFilePath: URL?
    }

    private struct ChunkResult {
        let index: Int
        let tempFilePath: URL
    }

    // MARK: - Public API

    /// Download all `chunks` from `url` using at most 6 concurrent tasks.
    ///
    /// - Parameters:
    ///   - downloadID:  Parent download identifier (used for task naming in engine).
    ///   - url:         The resource to download from.
    ///   - chunks:      Byte-range descriptors from ``ChunkManager``.
    ///   - tempDir:     Directory where `.partN` temp files will be written.
    ///   - onChunkComplete: Called per successfully downloaded chunk so the
    ///                  caller can persist ``ChunkRecord`` progress to SwiftData.
    func downloadAll(
        downloadID: UUID,
        url: URL,
        chunks: [ChunkRange],
        tempDir: URL,
        onChunkComplete: @Sendable @escaping (Int, URL) async -> Void
    ) async -> CoordinatorResult {
        var chunkTasks: [Int: ChunkTask] = Dictionary(
            uniqueKeysWithValues: chunks.map { ($0.index, ChunkTask(range: $0)) }
        )
        var completedPaths: [Int: URL] = [:]
        var permanentFailures = 0

        // Process in batches respecting maxConcurrentChunks
        var pending = chunks.map(\.index)

        while !pending.isEmpty && permanentFailures < 2 {
            if permanentFailures >= 2 {
                return .fallbackToSingleStream
            }

            let batch = Array(pending.prefix(maxConcurrentChunks))
            pending.removeFirst(min(maxConcurrentChunks, pending.count))

            let results = await withTaskGroup(
                of: Optional<ChunkResult>.self
            ) { group in
                for index in batch {
                    guard let chunkTask = chunkTasks[index] else { continue }
                    group.addTask { [chunkTask] in
                        await self.downloadChunk(
                            downloadID: downloadID,
                            url: url,
                            chunkTask: chunkTask,
                            tempDir: tempDir
                        )
                    }
                }

                var collected: [ChunkResult] = []
                for await result in group {
                    if let r = result { collected.append(r) }
                }
                return collected
            }

            for result in results {
                completedPaths[result.index] = result.tempFilePath
                chunkTasks[result.index]?.tempFilePath = result.tempFilePath
                await onChunkComplete(result.index, result.tempFilePath)
            }

            // Identify failed chunks from this batch and queue retries
            let completed = Set(results.map(\.index))
            for index in batch where !completed.contains(index) {
                guard var chunkTask = chunkTasks[index] else { continue }
                if chunkTask.retryCount < maxChunkRetries {
                    chunkTask.retryCount += 1
                    chunkTasks[index] = chunkTask
                    pending.insert(index, at: 0) // retry first
                } else {
                    permanentFailures += 1
                    if permanentFailures >= 2 {
                        return .fallbackToSingleStream
                    }
                }
            }
        }

        return .success(tempPaths: completedPaths)
    }

    // MARK: - Private

    private func downloadChunk(
        downloadID: UUID,
        url: URL,
        chunkTask: ChunkTask,
        tempDir: URL
    ) async -> ChunkResult? {
        let range = chunkTask.range
        var request = URLRequest(url: url)
        request.setValue(
            "bytes=\(range.start)-\(range.end)",
            forHTTPHeaderField: "Range"
        )

        for attempt in 0...maxChunkRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 206 || httpResponse.statusCode == 200
                else {
                    if attempt < maxChunkRetries { continue }
                    return nil
                }

                // Write to temp file
                let tempFile = tempDir.appendingPathComponent(
                    "\(downloadID.uuidString).part\(range.index)"
                )
                try data.write(to: tempFile, options: .atomic)
                return ChunkResult(index: range.index, tempFilePath: tempFile)

            } catch {
                if attempt < maxChunkRetries {
                    try? await Task.sleep(for: .seconds(pow(2.0, Double(attempt))))
                } else {
                    return nil
                }
            }
        }
        return nil
    }
}
