import ActivityKit
import Foundation

/// Manages Live Activity lifecycle for all active downloads.
///
/// All ActivityKit calls are guarded by availability and
/// `areActivitiesEnabled` checks so the app degrades gracefully
/// on unsupported devices.
actor LiveActivityManager {

    // MARK: - State

    /// Maps download ID → active Activity handle.
    private var activities: [UUID: Any] = [:]
    private var lastUpdateTimes: [UUID: Date] = [:]
    private let updateThrottleInterval: TimeInterval = 2.0

    // MARK: - Singleton

    static let shared = LiveActivityManager()

    // MARK: - Start

    /// Start a new Live Activity for a download item.
    ///
    /// No-ops when:
    /// - device doesn't support Live Activities
    /// - the user has disabled Live Activities in the app Settings
    /// - an activity for this download ID already exists (prevents duplicates on resume)
    func startActivity(for item: DownloadItem) async {
        await startActivity(id: item.id, fileName: item.fileName)
    }

    /// Primitive overload called from non-`@MainActor` contexts where passing a
    /// `DownloadItem` across isolation boundaries is unsafe.
    func startActivity(id: UUID, fileName: String) async {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Respect the in-app user toggle (missing key → true to preserve existing behaviour)
        let isEnabled = UserDefaults.standard.object(forKey: "liveActivitiesEnabled") as? Bool ?? true
        guard isEnabled else { return }

        // Prevent duplicate activities (e.g., on download resume)
        guard activities[id] == nil else { return }

        let attributes = DownloadAttributes(
            downloadID: id,
            fileName: fileName
        )
        let initialState = DownloadAttributes.ContentState(
            progressPercent: 0,
            speedBytesPerSecond: 0,
            estimatedSecondsRemaining: nil,
            statusRaw: DownloadStatus.running.rawValue
        )

        do {
            let activity = try Activity<DownloadAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            activities[id] = activity
        } catch {
            // ActivityKit not available or denied — degrade silently
        }
    }


    // MARK: - Update

    /// Push a progress update, throttled to at most once every 2 seconds.
    ///
    /// Pass `bypassThrottle: true` for the final completion state so the
    /// 100% update is never silently dropped by the throttle window.
    func updateActivity(
        id: UUID,
        state: DownloadAttributes.ContentState,
        bypassThrottle: Bool = false
    ) async {
        guard #available(iOS 16.2, *) else { return }

        let now = Date()
        if !bypassThrottle,
           let last = lastUpdateTimes[id],
           now.timeIntervalSince(last) < updateThrottleInterval {
            return
        }
        lastUpdateTimes[id] = now

        guard let activity = activities[id] as? Activity<DownloadAttributes> else { return }
        await activity.update(
            ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
        )
    }


    // MARK: - End

    /// End the Live Activity for a download.
    ///
    /// - Parameters:
    ///   - id:     Download identifier.
    ///   - policy: Dismissal timing. Use `.after(Date() + 5)` for success,
    ///             `.immediate` for error.
    func endActivity(id: UUID, policy: ActivityUIDismissalPolicy = .immediate) async {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = activities[id] as? Activity<DownloadAttributes> else { return }

        let finalState = DownloadAttributes.ContentState(
            progressPercent: 100,
            speedBytesPerSecond: 0,
            estimatedSecondsRemaining: nil,
            statusRaw: DownloadStatus.completed.rawValue
        )
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: policy
        )
        activities.removeValue(forKey: id)
        lastUpdateTimes.removeValue(forKey: id)
    }

    // MARK: - Convenience wrappers

    func endOnCompletion(id: UUID) async {
        guard #available(iOS 16.2, *) else { return }
        await endActivity(
            id: id,
            policy: .after(Date().addingTimeInterval(5))
        )
    }

    func endOnFailure(id: UUID) async {
        await endActivity(id: id, policy: .immediate)
    }
}
