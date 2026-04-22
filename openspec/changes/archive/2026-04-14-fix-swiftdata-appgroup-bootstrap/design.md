## Context

Downly uses SwiftData (built on CoreData) as its persistence layer. The `ModelContainer` is initialised in `DownlyApp.init()` via `AppModelContainer.makeContainer()`. The app declares the App Group `group.com.axoman.downly` in its entitlements. When no explicit `url` is given to `ModelConfiguration`, SwiftData resolves the default store path to the App Group container — specifically `<AppGroupContainer>/Library/Application Support/default.store`. CoreData requires the full parent path to exist before it can create the SQLite file; it does **not** create intermediate directories itself. The App Group container is created by the OS when any member app is installed, but the `Library/Application Support` subdirectory inside it is **not** created automatically — it must be bootstrapped by the application code.

## Goals / Non-Goals

**Goals:**
- Ensure `Library/Application Support` exists inside the App Group container before `ModelContainer` is constructed — eliminating the 880-line CoreData diagnostic dump on every cold launch.
- Make the store URL deterministic and auditable by passing an explicit `url` to `ModelConfiguration` rather than relying on opaque default resolution.
- Replace the `fatalError` in `DownlyApp.init` with a structured approach: crash in DEBUG (same behaviour, clearly intentional) and show a recovery screen in RELEASE (graceful degradation).

**Non-Goals:**
- Migrating to a new schema or store format.
- Moving the store out of the App Group (required by the Widget Extension).
- Adding SwiftData migration plans — that is a future concern.

## Decisions

### Decision 1: Create the directory inside `AppModelContainer.makeContainer()`

**Chosen**: `makeContainer()` resolves the App Group container URL via `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`, appends `Library/Application Support`, and calls `FileManager.default.createDirectory(at:withIntermediateDirectories:attributes:)` before constructing the `ModelContainer`. The store file is named `downly.store`.

**Alternative considered**: Create the directory in `DownlyApp.init()` before calling `makeContainer()`. Rejected — bootstrapping is a concern of `AppModelContainer`, not the app entry point. Keeping it in `makeContainer()` makes the function self-contained and testable in isolation.

**Alternative considered**: Use `ModelConfiguration(groupContainer: .identifier("group.com.axoman.downly"))`. This is the SwiftUI-only group container shorthand, but it still does not create the `Application Support` sub-directory and exhibits the same failure on simulators and devices. Rejected for the same reason.

**Rationale**: A one-time `createDirectory(withIntermediateDirectories: true)` call is idempotent (no-op if directory already exists) and costs a single filesystem stat call on subsequent launches.

### Decision 2: Explicit store URL `downly.store`

**Chosen**: Pass `url: appSupportURL.appendingPathComponent("downly.store")` to `ModelConfiguration`. This replaces the implicit `default.store` name and makes the path visible in code review and debugging.

**Rationale**: Explicit beats implicit. An opaque default resolution is what caused the original bug (we couldn't see where it was pointing without reading CoreData internals).

### Decision 3: Structured error handling in `DownlyApp.init`

**Chosen**: Define a private `enum ContainerError: Error` with a single case `unavailable(underlying: Error)`. On failure:
- `#if DEBUG`: `fatalError` with the full error description — keeps the crash-on-misconfiguration signal during development.
- Release: set a `@State var containerError: Error?` and show a `ContainerErrorView` overlay on `MainTabView` that prompts the user to restart.

**Rationale**: Production apps should never silently crash without user feedback. The recovery view is a minimal addition — one small SwiftUI view — that provides a restart prompt while preserving the hard-fail behaviour in DEBUG.

## Risks / Trade-offs

- **App Group ID hardcoded as a string**: `"group.com.axoman.downly"` is a string literal in `AppModelContainer`. The Widget Extension entitlements use the same value. If the group ID ever changes both must be updated. Mitigation: define it as a constant `AppModelContainer.appGroupID` and reference it from both targets.
- **`FileManager.containerURL` returns nil**: If the entitlements are misconfigured (e.g. on a simulator with a provisioning issue), `containerURL` returns `nil`. Mitigation: the guard in `makeContainer()` throws `ContainerError.unavailable` in release or `fatalError` in debug, giving a clear signal rather than a cryptic CoreData crash.
- **Store rename `default.store` → `downly.store`**: Any pre-existing simulator/device data stored under `default.store` will not be found. Since this is a bug fix at the `make` level and SwiftData performs migration, this is acceptable for a development-phase change. A migration plan is a non-goal.
