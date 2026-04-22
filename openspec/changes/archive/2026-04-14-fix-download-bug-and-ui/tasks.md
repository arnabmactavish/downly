## 1. Fix Download Engine Temp-File Race

- [x] 1.1 In `DownloadEngine.handleCompletion`, copy `tempLocation` to `FileManager.default.temporaryDirectory/<downloadID>.tmp` using `FileManager.copyItem(at:to:)` (overwriting if exists)
- [x] 1.2 If the copy succeeds, post `.downloadTaskDidFinish` with `userInfo` key `"stableLocation"` pointing to the copied URL — remove `"tempLocation"` from `userInfo`
- [x] 1.3 If the copy fails (catch block), post `.downloadTaskDidFail` with the copy error instead of `.downloadTaskDidFinish`

## 2. Fix Queue Manager Single-Stream Completion Handler

- [x] 2.1 In `DownloadQueueManager.waitForSingleStreamCompletion`, change the `"tempLocation"` key lookup to `"stableLocation"`
- [x] 2.2 After a successful `FileManager.moveItem`, delete the stable copy at `stableLocation` using `try? FileManager.default.removeItem(at:)`
- [x] 2.3 In the error path (move fails), also delete `stableLocation` to avoid temp file accumulation, then call `markError`

## 3. Refactor Navigation Bar Toolbar

- [x] 3.1 In `DownloadListView`, add an `.topBarTrailing` `ToolbarItem` with a plain `Button(action: { showAddSheet = true })` containing `Image(systemName: "plus")` — no background modifier
- [x] 3.2 Change the existing Settings `ToolbarItem` (`.topBarTrailing`) from `FloatingOvalButton` to a plain `Button(action: { showSettings = true })` containing `Image(systemName: "gearshape")` — no background modifier
- [x] 3.3 Apply `.font(.system(size: 17, weight: .semibold))` and `.foregroundStyle(DS.Colors.label)` to both new toolbar icon buttons for consistent appearance
- [x] 3.4 Remove `AddDownloadFAB { showAddSheet = true }` and its wrapping `HStack`/`Spacer` from the bottom `VStack` overlay, leaving only `FloatingBottomNavBar`

## 4. Clean Up FloatingBottomNavBar Glass

- [x] 4.1 Add a `showFill: Bool = true` parameter to `LiquidGlassBackground` (or the `liquidGlass` extension); when `false`, skip the `DS.Colors.glassFill` overlay layer
- [x] 4.2 Update `FloatingBottomNavBar` to call `.liquidGlass(cornerRadius: DS.Radius.pill, showFill: false)` so it renders pure `ultraThinMaterial` without the semi-transparent colour tint

## 5. Remove FloatingOvalButton Background from Edit Toolbar

- [x] 5.1 Replace the leading `FloatingOvalButton(icon: "pencil", label: "Edit")` in `DownloadListView` with a plain `Button` containing `HStack { Image(systemName: "pencil"); Text("Edit") }` (no liquid-glass modifier) — or apply `showBackground: false` if that approach is preferred from the design
- [x] 5.2 Similarly update `editModeToolbar` — replace `FloatingOvalButton` wrappers for Delete and Done with plain labelled `Button` views styled with `DS.Colors.label` foreground colour
