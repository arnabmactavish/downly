import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct DownlyApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let modelContainer: ModelContainer

    @StateObject private var queueManager: DownloadQueueManager

    /// Non-nil when `makeContainer()` fails in a release build.
    /// Triggers the `ContainerErrorView` overlay so the user can restart.
    @State private var containerSetupError: Error?

    init() {
        do {
            let container = try AppModelContainer.makeContainer()
            self.modelContainer = container

            // Task 10.5 — Provide queueManager to environment via StateObject.
            // Queue restore is called in the root view's .task modifier below.
            let context = container.mainContext
            let manager = DownloadQueueManager(modelContext: context)
            _queueManager = StateObject(wrappedValue: manager)

        } catch {
#if DEBUG
            // Crash loudly in dev so misconfiguration is caught immediately.
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
#else
            // In release, fall back to an in-memory store so the app body can
            // render, then surface ContainerErrorView prompting a restart.
            let fallback = try! ModelContainer(
                for: AppModelContainer.schema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
            self.modelContainer = fallback
            let manager = DownloadQueueManager(modelContext: fallback.mainContext)
            _queueManager = StateObject(wrappedValue: manager)
            _containerSetupError = State(initialValue: error)
#endif
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(modelContainer)
                .environmentObject(queueManager)
                // Task 10.5 — Restore queue on launch
                .task {
                    // Skip queue restore when running on in-memory fallback —
                    // there is no persisted state to restore.
                    guard containerSetupError == nil else { return }
                    queueManager.restoreQueueOnLaunch()

                    // Task 5.6 — Orphan temp file cleanup on launch
                    let descriptor = FetchDescriptor<DownloadItem>(
                        predicate: #Predicate {
                            $0.statusRaw == "running" ||
                            $0.statusRaw == "pending" ||
                            $0.statusRaw == "interrupted"
                        }
                    )
                    let activeIDs = (try? modelContainer.mainContext.fetch(descriptor))
                        .map { Set($0.map(\.id.uuidString)) } ?? []

                    FileAssemblyEngine().cleanupOrphanedTempFiles(
                        activeDownloadIDs: activeIDs
                    )
                }
                .overlay {
                    if let error = containerSetupError {
                        ContainerErrorView(error: error)
                    }
                }
        }
    }
}

// MARK: - AppDelegate

/// Handles UIKit lifecycle hooks required for background URLSession support.
///
/// Task 10.6 — receives the background session completion handler from the system.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Touch the singleton early so the background URLSession delegate is
        // reconnected before the system delivers pending events from a cold
        // launch triggered by nsurlsessiond.
        _ = DownloadEngine.shared
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Store the completion handler. DownloadEngine will call it in
        // urlSessionDidFinishEvents(forBackgroundURLSession:).
        Task {
            await DownloadEngine.shared.storeBackgroundCompletionHandler(completionHandler)
        }
    }
}
