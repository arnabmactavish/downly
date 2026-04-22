import Foundation

/// Errors raised by the download operation state machine.
enum DownloadOperationError: Error {
    case invalidStateTransition(from: DownloadStatus, to: DownloadStatus)
    case missingModelContext
}

/// An `Operation` subclass that encapsulates the full lifecycle of
/// one file download: server analysis → chunking → download → merge → completion.
///
/// Conforms to the async-compatible `AsyncOperation` pattern so that
/// Swift Concurrency tasks can run inside an `OperationQueue`.
final class DownloadOperation: Operation {

    // MARK: - Properties

    let downloadID: UUID

    override var isAsynchronous: Bool { true }
    override var isExecuting: Bool {
        get { _isExecuting }
        set {
            willChangeValue(for: \.isExecuting)
            _isExecuting = newValue
            didChangeValue(for: \.isExecuting)
        }
    }
    override var isFinished: Bool {
        get { _isFinished }
        set {
            willChangeValue(for: \.isFinished)
            _isFinished = newValue
            didChangeValue(for: \.isFinished)
        }
    }

    private var _isExecuting = false
    private var _isFinished  = false

    /// Closure that performs the actual download work.
    private let work: @Sendable () async -> Void

    // MARK: - Init

    init(downloadID: UUID, work: @escaping @Sendable () async -> Void) {
        self.downloadID = downloadID
        self.work = work
        super.init()
        self.name = downloadID.uuidString
    }

    // MARK: - Execution

    override func start() {
        guard !isCancelled else {
            isFinished = true
            return
        }
        isExecuting = true
        Task { [weak self] in
            guard let self else { return }
            await self.work()
            self.isExecuting = false
            self.isFinished  = true
        }
    }
}
