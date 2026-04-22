import Foundation
import OSLog

/// A progress snapshot delivered to observers from the download engine.
struct DownloadProgress: Sendable {
    let downloadID: UUID
    let bytesWritten: Int64
    let totalBytesWritten: Int64
    let totalBytesExpected: Int64

    var percent: Double {
        guard totalBytesExpected > 0 else { return 0 }
        return min(Double(totalBytesWritten) / Double(totalBytesExpected) * 100, 100)
    }

    var speed: Int64  // bytes per second (computed externally)
    var estimatedSecondsRemaining: Int?
}

/// Errors surfaced by the download engine.
enum DownloadEngineError: Error {
    case taskNotFound(UUID)
    case noResumeData
    case invalidResponse(Int)
    case cancelled
    case underlyingError(Error)
}

/// Identifies the nature of a network error so the retry logic can
/// decide whether to attempt a re-connection.
private func isTransientError(_ error: Error) -> Bool {
    let nsError = error as NSError
    let transientCodes: Set<Int> = [
        NSURLErrorNetworkConnectionLost,
        NSURLErrorNotConnectedToInternet,
        NSURLErrorTimedOut,
        NSURLErrorCannotConnectToHost,
        NSURLErrorDNSLookupFailed,
    ]
    return nsError.domain == NSURLErrorDomain && transientCodes.contains(nsError.code)
}

// MARK: -

/// Core download engine backed by a URLSession background session.
///
/// One shared instance handles all active tasks. Tasks are associated
/// with download IDs via `taskDescription`.
actor DownloadEngine: NSObject {

    // MARK: - Types

    typealias ProgressStream = AsyncStream<DownloadProgress>

    private struct ActiveTask {
        let downloadID: UUID
        let task: URLSessionDownloadTask
        var retryCount: Int = 0
        var lastProgressTime: Date = .distantPast
        var lastBytesWritten: Int64 = 0
        var lastSpeedSampleTime: Date = Date()
        var speed: Int64 = 0
    }

    // MARK: - State

    // URLSession must be set after `super.init()` because we pass `self` as delegate.
    private var session: URLSession!
    private var activeTasks: [UUID: ActiveTask] = [:]
    private var progressContinuations: [UUID: AsyncStream<DownloadProgress>.Continuation] = [:]

    /// Stored by AppDelegate so we can call it in `urlSessionDidFinishEvents`.
    /// It is a plain sync closure (system requirement).
    private(set) var backgroundCompletionHandler: (() -> Void)?

    // MARK: - Singleton

    static let shared = DownloadEngine()

    // MARK: - Init

    override init() {
        super.init()
        // Use a default (foreground) session so that delegate callbacks
        // (didWriteData, didFinishDownloading) are delivered reliably while
        // the app is in the foreground. Background sessions require an explicit
        // entitlement and silently fail in the Simulator.
        let config = URLSessionConfiguration.default
        // Back-pressure: don't allow more than 6 simultaneous socket connections
        // across all downloads (system may further restrict this).
        config.httpMaximumConnectionsPerHost = 6

        // `self` is safe here because actor isolation is enforced at runtime
        // and the delegate is only called on URLSession's delegate queue.
        session = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
    }

    // MARK: - Public API

    /// Begin a download for `url`, identified by `downloadID`.
    /// Returns an `AsyncStream` of progress updates throttled to 0.5 s.
    @discardableResult
    func startDownload(
        id downloadID: UUID,
        url: URL,
        resumeData: Data? = nil
    ) -> ProgressStream {
        let task: URLSessionDownloadTask
        if let data = resumeData {
            task = session.downloadTask(withResumeData: data)
        } else {
            task = session.downloadTask(with: url)
        }
        task.taskDescription = downloadID.uuidString
        task.resume()

        let (stream, continuation) = ProgressStream.makeStream()
        progressContinuations[downloadID] = continuation
        activeTasks[downloadID] = ActiveTask(downloadID: downloadID, task: task)

        DownlyLogger.logStart(id: downloadID, url: url)
        return stream
    }

    /// Begin a chunked partial download using an HTTP Range header.
    @discardableResult
    func startChunkDownload(
        id downloadID: UUID,
        chunkIndex: Int,
        url: URL,
        rangeStart: Int64,
        rangeEnd: Int64
    ) -> ProgressStream {
        var request = URLRequest(url: url)
        request.setValue("bytes=\(rangeStart)-\(rangeEnd)", forHTTPHeaderField: "Range")

        let task = session.downloadTask(with: request)
        // Encode both download ID and chunk index into the description
        task.taskDescription = "\(downloadID.uuidString)|\(chunkIndex)"
        task.resume()

        let (stream, continuation) = ProgressStream.makeStream()
        progressContinuations[downloadID] = continuation
        activeTasks[downloadID] = ActiveTask(downloadID: downloadID, task: task)

        return stream
    }

    /// Pause an active download, persisting resumeData via the provided closure.
    func pauseDownload(
        id downloadID: UUID,
        persistResume: @escaping @Sendable (Data?) -> Void
    ) async {
        guard let entry = activeTasks[downloadID] else { return }
        entry.task.cancel(byProducingResumeData: { data in
            Task { persistResume(data) }
        })
        activeTasks.removeValue(forKey: downloadID)
        progressContinuations[downloadID]?.finish()
        progressContinuations.removeValue(forKey: downloadID)
    }

    /// Cancel and remove a download.
    func cancelDownload(id downloadID: UUID) {
        activeTasks[downloadID]?.task.cancel()
        activeTasks.removeValue(forKey: downloadID)
        progressContinuations[downloadID]?.finish()
        progressContinuations.removeValue(forKey: downloadID)
    }

    /// Store the system-provided completion handler from AppDelegate.
    func storeBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        backgroundCompletionHandler = handler
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadEngine: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let desc = downloadTask.taskDescription,
              let downloadID = UUID(uuidString: String(desc.split(separator: "|").first ?? Substring(desc)))
        else { return }

        Task { await self.handleProgress(
            downloadID: downloadID,
            bytesWritten: bytesWritten,
            totalBytesWritten: totalBytesWritten,
            totalBytesExpected: totalBytesExpectedToWrite
        ) }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let desc = downloadTask.taskDescription else { return }
        let parts = desc.split(separator: "|")
        guard let downloadID = UUID(uuidString: String(parts[0])) else { return }
        let chunkIndex = parts.count > 1 ? Int(parts[1]) : nil

        // ── Synchronous copy while the delegate is still on the call stack ──
        // URLSession's contract: `location` is valid ONLY for the duration of
        // this method call. iOS deletes the CFNetworkDownload_*.tmp file the
        // moment we return. We must copy it to a stable path NOW, on the
        // delegate's background queue, before dispatching the async Task.
        let fm = FileManager.default
        guard let appGroupURL = fm.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.axoman.downly"
        ) else {
            Task { await self.postFailure(downloadID: downloadID, message: "App Group container unavailable") }
            return
        }

        let stagingDir  = appGroupURL.appendingPathComponent("tmp", isDirectory: true)
        let stableURL   = stagingDir.appendingPathComponent("\(downloadID.uuidString).tmp")

        do {
            try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: stableURL.path) {
                try fm.removeItem(at: stableURL)
            }
            try fm.copyItem(at: location, to: stableURL) // synchronous disk-to-disk copy
        } catch {
            Task { await self.postFailure(downloadID: downloadID, message: error.localizedDescription) }
            return
        }

        // Temp file is now safely copied — dispatch the rest asynchronously.
        Task {
            await self.handleCompletion(
                downloadID: downloadID,
                chunkIndex: chunkIndex,
                stableLocation: stableURL
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error, let desc = task.taskDescription,
              let downloadID = UUID(uuidString: String(desc.split(separator: "|").first ?? Substring(desc)))
        else { return }

        Task { await self.handleError(downloadID: downloadID, error: error) }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task {
            await self.invokeBackgroundCompletionHandler()
        }
    }
}

// MARK: - Private delegate handlers

private extension DownloadEngine {

    func handleProgress(
        downloadID: UUID,
        bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpected: Int64
    ) {
        let now = Date()
        guard var entry = activeTasks[downloadID] else { return }

        // Throttle: deliver at most once per 0.5 s
        guard now.timeIntervalSince(entry.lastProgressTime) >= 0.5 else { return }

        // Simple speed calculation: bytes delta / time delta
        let timeDelta = now.timeIntervalSince(entry.lastSpeedSampleTime)
        let bytesDelta = totalBytesWritten - entry.lastBytesWritten
        let speed: Int64 = timeDelta > 0 ? Int64(Double(bytesDelta) / timeDelta) : entry.speed

        var eta: Int?
        let remaining = totalBytesExpected - totalBytesWritten
        if speed > 0 && remaining > 0 {
            eta = Int(Double(remaining) / Double(speed))
        }

        entry.lastProgressTime     = now
        entry.lastBytesWritten     = totalBytesWritten
        entry.lastSpeedSampleTime  = now
        entry.speed                = speed
        activeTasks[downloadID]    = entry

        let progress = DownloadProgress(
            downloadID: downloadID,
            bytesWritten: bytesWritten,
            totalBytesWritten: totalBytesWritten,
            totalBytesExpected: totalBytesExpected,
            speed: speed,
            estimatedSecondsRemaining: eta
        )
        progressContinuations[downloadID]?.yield(progress)
        DownlyLogger.logProgress(
            id: downloadID,
            bytesWritten: totalBytesWritten,
            totalBytes: totalBytesExpected,
            speed: speed
        )
    }

    func handleCompletion(
        downloadID: UUID,
        chunkIndex: Int?,
        stableLocation: URL
    ) {
        // The file at `stableLocation` was already copied synchronously inside
        // `didFinishDownloadingTo` before this Task was dispatched, so the path
        // is guaranteed to exist on disk at this point.
        progressContinuations[downloadID]?.finish()
        progressContinuations.removeValue(forKey: downloadID)
        activeTasks.removeValue(forKey: downloadID)

        DownlyLogger.logCompletion(id: downloadID, path: stableLocation.path)

        let info: [String: Any?] = [
            "downloadID": downloadID,
            "chunkIndex": chunkIndex,
            "stableLocation": stableLocation,
        ]
        NotificationCenter.default.post(
            name: .downloadTaskDidFinish,
            object: nil,
            userInfo: info as [AnyHashable: Any]
        )
    }

    /// Posts a `.downloadTaskDidFail` notification with a plain string message.
    /// Useful from `nonisolated` delegate context where only a `Task` can hop
    /// back to the actor.
    func postFailure(downloadID: UUID, message: String) {
        progressContinuations[downloadID]?.finish()
        progressContinuations.removeValue(forKey: downloadID)
        activeTasks.removeValue(forKey: downloadID)

        let error = NSError(
            domain: "DownloadEngine",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        DownlyLogger.logFileError(id: downloadID, label: "staging", error: error)
        NotificationCenter.default.post(
            name: .downloadTaskDidFail,
            object: nil,
            userInfo: [
                "downloadID": downloadID,
                "error": error,
            ] as [AnyHashable: Any]
        )
    }

    func handleError(downloadID: UUID, error: Error) {
        guard var entry = activeTasks[downloadID] else { return }

        if isTransientError(error) && entry.retryCount < 3 {
            entry.retryCount += 1
            activeTasks[downloadID] = entry

            DownlyLogger.logError(id: downloadID, error: error)
            let delay = pow(2.0, Double(entry.retryCount))
            Task {
                try? await Task.sleep(for: .seconds(delay))
                await self.retryDownload(entry: entry)
            }
        } else {
            activeTasks.removeValue(forKey: downloadID)
            progressContinuations[downloadID]?.finish()
            progressContinuations.removeValue(forKey: downloadID)

            DownlyLogger.logError(id: downloadID, error: error)
            NotificationCenter.default.post(
                name: .downloadTaskDidFail,
                object: nil,
                userInfo: [
                    "downloadID": downloadID,
                    "error": error,
                ] as [AnyHashable: Any]
            )
        }
    }

    private func retryDownload(entry: ActiveTask) {
        guard let originalURL = entry.task.originalRequest?.url else { return }
        let desc = entry.task.taskDescription
        let chunkIndex = desc.flatMap { d -> Int? in
            let parts = d.split(separator: "|")
            return parts.count > 1 ? Int(parts[1]) : nil
        }

        if let chunkIndex {
            // Re-issue chunk request
            let newTask = session.downloadTask(with: entry.task.originalRequest!)
            newTask.taskDescription = "\(entry.downloadID.uuidString)|\(chunkIndex)"
            newTask.resume()
            activeTasks[entry.downloadID] = ActiveTask(
                downloadID: entry.downloadID,
                task: newTask,
                retryCount: entry.retryCount
            )
        } else {
            _ = startDownload(id: entry.downloadID, url: originalURL)
        }
    }

    func invokeBackgroundCompletionHandler() {
        // backgroundCompletionHandler is a plain non-async closure — call directly.
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let downloadTaskDidFinish = Notification.Name("com.downly.downloadTaskDidFinish")
    static let downloadTaskDidFail   = Notification.Name("com.downly.downloadTaskDidFail")
}
