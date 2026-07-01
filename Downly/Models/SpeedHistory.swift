import Foundation
import Combine

// MARK: - SpeedSample

/// A single speed measurement recorded at a point in time.
struct SpeedSample: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let bytesPerSecond: Int64
}

// MARK: - SpeedHistory

/// A fixed-capacity ring buffer that stores the last `capacity` speed samples
/// for a single download. Designed for the detail sheet speed graph.
///
/// Not thread-safe — always access on @MainActor.
@MainActor
final class SpeedHistory: ObservableObject {

    // MARK: - Configuration

    static let capacity = 60

    // MARK: - State

    @Published private(set) var samples: [SpeedSample] = []

    // MARK: - API

    /// Appends a new speed sample, dropping the oldest if at capacity.
    func record(bytesPerSecond: Int64) {
        let sample = SpeedSample(timestamp: Date(), bytesPerSecond: bytesPerSecond)
        if samples.count >= SpeedHistory.capacity {
            samples.removeFirst()
        }
        samples.append(sample)
    }

    /// Clears all recorded samples.
    func reset() {
        samples.removeAll()
    }

    /// Peak speed observed across all samples.
    var peakBytesPerSecond: Int64 {
        samples.map(\.bytesPerSecond).max() ?? 0
    }

    /// Latest speed sample value, or 0 if no samples recorded.
    var latestBytesPerSecond: Int64 {
        samples.last?.bytesPerSecond ?? 0
    }
}

// MARK: - SpeedHistoryStore

/// Global registry of per-download SpeedHistory instances.
/// The detail sheet accesses this to bind to the live speed graph.
@MainActor
final class SpeedHistoryStore {

    static let shared = SpeedHistoryStore()

    private var histories: [UUID: SpeedHistory] = [:]

    /// Returns the SpeedHistory for the given download, creating one if needed.
    func history(for downloadID: UUID) -> SpeedHistory {
        if let existing = histories[downloadID] {
            return existing
        }
        let new = SpeedHistory()
        histories[downloadID] = new
        return new
    }

    /// Removes the history for a completed or cancelled download.
    func remove(for downloadID: UUID) {
        histories.removeValue(forKey: downloadID)
    }
}
