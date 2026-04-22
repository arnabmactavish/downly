import Foundation

/// Represents the lifecycle state of a single download item.
enum DownloadStatus: String, Codable, CaseIterable {
    case pending
    case running
    case paused
    case completed
    case error
    case interrupted

    var displayName: String {
        switch self {
        case .pending:     return "Pending"
        case .running:     return "Downloading"
        case .paused:      return "Paused"
        case .completed:   return "Done"
        case .error:       return "Error"
        case .interrupted: return "Interrupted"
        }
    }

    /// Returns true if this is a terminal state (no further automatic progress).
    var isTerminal: Bool {
        switch self {
        case .completed, .error: return true
        default:                 return false
        }
    }

    /// Valid transitions from the current state.
    func canTransition(to newStatus: DownloadStatus) -> Bool {
        switch (self, newStatus) {
        case (.pending, .running),
             (.running, .paused),
             (.running, .completed),
             (.running, .error),
             (.running, .interrupted),
             (.paused, .running),
             (.paused, .error),
             (.interrupted, .running),
             (.interrupted, .error),
             (.error, .running):   // retry
            return true
        default:
            return false
        }
    }
}

/// Represents the state of an individual chunk download.
enum ChunkStatus: String, Codable {
    case pending
    case downloading
    case completed
    case failed
}
