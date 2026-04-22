## Why

On launch, Downly's SwiftData store fails to initialise because the `Library/Application Support` directory does not exist inside the App Group container (`group.com.axoman.downly`). CoreData (which SwiftData uses internally) tries to write `default.store` directly into that directory, receives `errno 2` (no such file or directory), logs 880+ lines of "sandbox access denied" diagnostics, and falls back to a recovery path. The recovery eventually succeeds, but the failure loop is fragile, logs noisy diagnostics in production, and could regress on devices where recovery is slower or the sandbox environment behaves differently.

The root cause is that `AppModelContainer.makeContainer()` passes a `ModelConfiguration` without an explicit store URL. SwiftData's default store resolver targets the App Group container (because the app has `group.com.axoman.downly` in its entitlements) but never creates the `Application Support` subdirectory before handing the path to CoreData.

## What Changes

- **Pre-create `Application Support` directory**: Before constructing the `ModelContainer`, use `FileManager` to create `containerURL/Library/Application Support` for the app group, ensuring CoreData never encounters a missing parent directory.
- **Explicit store URL in `ModelConfiguration`**: Supply an explicit `url` to `ModelConfiguration` so the store location is deterministic — pointing inside the App Group's `Application Support` directory at `downly.store` — rather than relying on SwiftData's opaque default resolver.
- **Graceful error surfacing in `DownlyApp`**: Replace the bare `fatalError` in `DownlyApp.init` with a structured error type that surfaces a user-visible recovery screen in release builds while still crashing in DEBUG.

## Capabilities

### New Capabilities

- None — this is a correctness fix, not a feature addition.

### Modified Capabilities

- `persistence-layer`: `AppModelContainer` now explicitly manages store URL resolution and parent directory bootstrap.

## Impact

- **`Downly/Persistence/AppModelContainer.swift`** — `makeContainer()`: resolve App Group container URL, create `Application Support` directory if needed, pass explicit `url` to `ModelConfiguration`.
- **`Downly/App/DownlyApp.swift`** — `init()`: replace `fatalError` with a recoverable error pattern; show `ContainerErrorView` in the failure branch.
