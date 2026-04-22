## ADDED Requirements

### Requirement: DownlyLogger structured logging utility
The app SHALL provide a `DownlyLogger` type using `os.Logger` as the backing store, with `#if DEBUG` console print statements for all download lifecycle events.

#### Scenario: Logger available at module scope
- **WHEN** any Swift file imports Foundation in the Downly target
- **THEN** `DownlyLogger` MUST be accessible via a shared instance or static methods without additional imports

#### Scenario: Debug print emitted for download start
- **WHEN** a download begins in a DEBUG build
- **THEN** `DownlyLogger` MUST print a line containing `[Downly]`, the download UUID, the URL, and the label `"start"` to the Xcode console

#### Scenario: Debug print emitted for progress
- **WHEN** a throttled progress event fires in a DEBUG build
- **THEN** `DownlyLogger` MUST print a line containing the download UUID, bytes written, total expected bytes, and current speed in bytes/sec

#### Scenario: Debug print emitted for completion
- **WHEN** a download finishes (success or failure) in a DEBUG build
- **THEN** `DownlyLogger` MUST print a line containing the download UUID and the outcome (`"completed"` or `"failed: <reason>"`)

#### Scenario: No console output in release
- **WHEN** the app is compiled with `DEBUG` undefined (Release configuration)
- **THEN** `DownlyLogger` MUST NOT call `print()` or `NSLog()` or any other console output mechanism; `os.Logger` calls are permitted as they are runtime-controlled

### Requirement: Files app visibility via Info.plist
The app SHALL declare `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` as `YES` in `Info.plist` so the iOS Files app can browse and open downloaded files.

#### Scenario: Files app shows Downly folder
- **WHEN** the user opens the iOS Files app and navigates to On My iPhone / Downly
- **THEN** the folder MUST be visible and downloadable files inside it MUST be listed

#### Scenario: Documents accessible via document picker
- **WHEN** another app invokes a document picker
- **THEN** files in Downly's Documents directory MUST be selectable
