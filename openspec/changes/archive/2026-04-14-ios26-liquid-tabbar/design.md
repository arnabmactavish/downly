## Context
iOS 26 deprecates legacy vibrancy and manual `ultraThinMaterial` constructions in favor of true Liquid Glass hardware-accelerated rendering. Implementing the new native `GlassEffectView` and associated `.glassEffect()` modifiers ensures optimal performance, accurate visual refraction against arbitrary backgrounds, and integrates the system's expected interaction models seamlessly.

## Goals / Non-Goals
**Goals:**
- Migrate bottom navigation fully to native TabView/GlassEffect mechanics according to iOS 26 standards.
- Enforce system-drawn active-tab capsules in place of manual UI highlighting.
- Refactor the underlying views to permit true background bleed-through without conflicting manual padding boundaries.

**Non-Goals:**
- Implementing any custom particle, background fill, or shape behaviors to "simulate" iOS 26 functionality. It must be authentically native.

## Decisions
- **Architecture Replacement**: `DownloadListView` currently emulates tabs via an `HStack` inside `.safeAreaInset`. This will be stripped out and replaced with iOS 26's dedicated glass container behaviors (e.g., using a native `.glassEffect()` modifier).
- **Indicator Lifecycle Handover**: All `.matchedGeometryEffect` or implicit shape properties mapped to state changes will be deleted; `.symbolVariants(.fill)` via SF Symbols will take their place upon active state selection, while the system will apply the background capsule natively via the native layout.
- **Scroll Content Alignment**: The `ScrollView` bounds will intersect naturally with the safe boundaries, utilizing `.contentMargins(.bottom, ...)` (or analogous system properties) simply to evade hard collisions without hacking the `edgesIgnoringSafeArea`/`ignoresSafeArea` bounds. 

## Risks / Trade-offs
- **Customization Limitations**: Relying 100% on the system `.glassEffect()` eliminates granular control over border densities or specular highlights. We accept native behaviors as ultimate ground truth.
