import SwiftUI
import SwiftData

/// Configures the shared ``ModelContainer`` for the Downly app.
///
/// All SwiftData models are registered here. Future schema versions
/// should be added as a migration plan rather than dropping the store.
enum AppModelContainer {

    // MARK: - Constants

    /// App Group identifier shared by the main app and Widget Extension.
    /// Must match the value in both targets' `.entitlements` files.
    static let appGroupID = "group.com.axoman.downly"

    static let schema = Schema([
        DownloadItem.self,
        ChunkRecord.self,
    ])

    // MARK: - Container

    /// Production container with explicit store URL inside the App Group.
    ///
    /// Bootstraps `Library/Application Support` if it doesn't exist — CoreData
    /// does **not** create intermediate parent directories, which caused an
    /// 880-line diagnostic flood and an `NSCocoaErrorDomain 512` failure on
    /// every first launch (or after the simulator resets its shared container).
    ///
    /// Throws ``ContainerError`` on misconfiguration — callers should crash in
    /// DEBUG and surface a recovery UI in release builds.
    static func makeContainer() throws -> ModelContainer {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            throw ContainerError.appGroupUnavailable(id: appGroupID)
        }

        let appSupportURL = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        // Idempotent — no-op if the directory already exists.
        try FileManager.default.createDirectory(
            at: appSupportURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let storeURL = appSupportURL.appendingPathComponent("downly.store")

        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

// MARK: - ContainerError

/// Errors that can occur when constructing the SwiftData ``ModelContainer``.
enum ContainerError: Error, LocalizedError {

    /// The App Group container URL could not be resolved.
    /// Usually indicates a misconfigured entitlement.
    case appGroupUnavailable(id: String)

    /// Wraps an underlying ``Error`` from the store creation attempt.
    case unavailable(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable(let id):
            return "App Group '\(id)' is not available. Check entitlements."
        case .unavailable(let error):
            return "Storage unavailable: \(error.localizedDescription)"
        }
    }
}
