## 1. Harden `AppModelContainer`

- [x] 1.1 Add `static let appGroupID = "group.com.axoman.downly"` constant to `AppModelContainer` enum — single source of truth for the group identifier used by both the app and Widget targets.
- [x] 1.2 In `makeContainer()`, resolve the App Group container URL:
  ```swift
  guard let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupID
  ) else {
      // fatalError in DEBUG, throw ContainerError.unavailable in release
  }
  ```
- [x] 1.3 Compute `appSupportURL = containerURL.appendingPathComponent("Library/Application Support")` and call `FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)` — wrap in `try` and let the error propagate; it is a no-op when the directory already exists.
- [x] 1.4 Build `storeURL = appSupportURL.appendingPathComponent("downly.store")`.
- [x] 1.5 Replace the existing `ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)` with `ModelConfiguration(schema: schema, url: storeURL)` — explicit URL, not in-memory.
- [x] 1.6 Remove `static let modelConfiguration` computed property (it is now constructed inline in `makeContainer()`).

## 2. Refine Error Handling in `DownlyApp`

- [x] 2.1 Add `@State private var containerSetupError: Error? = nil` to `DownlyApp`.
- [x] 2.2 In the `catch` block of `DownlyApp.init()`:
  - `#if DEBUG` → keep the existing `fatalError("Failed to create SwiftData ModelContainer: \(error)")`.
  - `#else` → assign `_containerSetupError = State(initialValue: error)` and initialise `modelContainer` to an in-memory fallback: `try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))`. Set `_queueManager` to a dummy manager on the in-memory context so the body compiles without force-unwrap issues.
- [x] 2.3 In `body`, attach `.overlay` on `MainTabView()` that conditionally shows `ContainerErrorView` when `containerSetupError != nil`.

## 3. Add `ContainerErrorView`

- [x] 3.1 Create `Downly/UI/Screens/ContainerErrorView.swift` — a simple SwiftUI `View` that shows an SF Symbol (e.g. `exclamationmark.triangle`), a title `"Storage Unavailable"`, a localised description of the error, and a `Button("Restart App")` that calls `exit(0)` (acceptable for this error class — data store unavailability is unrecoverable at runtime).
- [x] 3.2 Style `ContainerErrorView` with `DS.Colors` and typography consistent with the rest of Downly — dark background, white text, red accent on the icon.

## 4. Propagate `appGroupID` to Widget Extension

- [x] 4.1 Open `DownlyWidgetExtensionExtension.entitlements` and verify `com.apple.security.application-groups` contains `group.com.axoman.downly` — confirmed it matches `AppModelContainer.appGroupID` (read-only audit, no code change needed).
- [x] 4.2 The Widget target (`DownloadLiveActivityWidget`) is a pure Live Activity widget with no `ModelContainer` construction — no changes required.
