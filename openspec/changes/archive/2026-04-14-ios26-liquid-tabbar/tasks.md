## 1. Purge Legacy Effects & Manual Styling
- [x] 1.1 In `NavigationComponents.swift`, strip `.background(.ultraThinMaterial)` and any custom explicit borders or legacy `.liquidGlass(...)` modifiers entirely off the structure representing the navigation bar.
- [x] 1.2 In `NavigationComponents.swift`, delete custom active state trackers manually drawing `.background { if isSelected { RoundedRectangle... } }` against the underlying tab element properties in `NavBarTab`.
- [x] 1.3 Transition all selection evaluation inside `NavBarTab` to rely intrinsically upon the `.symbolVariants(.fill)` modifier, entirely relinquishing manual highlight/selection configurations to the system.

## 2. Provision iOS 26 Container API Elements
- [x] 2.1 Refactor `FloatingBottomNavBar` internals to encapsulate navigation bindings within standard container expectations compatible with true native `.glassEffect()`.
- [x] 2.2 Re-architect the root structure of the tab container to explicitly pass `.glassEffect(GlassEffect(), in: .capsule)` (or `ContainerRelativeShape`) according strictly to iOS 26 material behavior standards. Do NOT apply `.tint()` unless explicitly attempting to tint the underlying layout. 

## 3. Structural Re-Alignment
- [x] 3.1 In `DownloadListView.swift`, dismantle the localized wrapper dictating `.safeAreaInset(edge: .bottom)` forcing manual constraints on the bottom rendering node.
- [x] 3.2 Repoint the central `ScrollView` layout to assign `.contentMargins(.bottom, ..., for: .scrollContent)` behavior natively, preventing the main feed from clipping illegally or failing to refract through the glass API appropriately relative to the system frame boundaries.
- [x] 3.3 Restructure the detached Settings Action button layout parameter utilizing analogous `.glassEffect` mechanics matching the strict paradigm enforced on the tab segment.
