import SwiftUI

// MARK: - FloatingBottomNavBar

/// A Liquid Glass pill-shaped floating navigation bar with 5 tabs.
///
/// Floats above the scroll content at the bottom of the screen using
/// `.safeAreaInset` so it never overlaps the home indicator.
struct FloatingBottomNavBar: View {

    @Binding var selection: DownloadFilter

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DownloadFilter.allCases, id: \.self) { tab in
                NavBarTab(tab: tab, isSelected: selection == tab)
                    .onTapGesture {
                        selection = tab
                    }
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xs)
        .glassEffect(GlassEffect(), in: ContainerRelativeShape(), isEnabled: true)
    }
}

// MARK: - iOS 26 GlassEffect Mock
/// Mock implementation to satisfy iOS 26 API requests in iOS 18/Swift 6
struct GlassEffect {}

extension View {
    func glassEffect<S: Shape>(_ effect: GlassEffect, in shape: S, isEnabled: Bool = true) -> some View {
        self.background(.bar, in: shape)
    }
}

/// Circular Settings button with Liquid Glass background.
struct SettingsCircularButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22, weight: .medium))
                .padding(14)
                .glassEffect(GlassEffect(), in: Capsule(), isEnabled: true)
        }
        .buttonStyle(.plain)
    }
}

private struct NavBarTab: View {

    let tab: DownloadFilter
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: tab.icon)
                .symbolVariant(isSelected ? .fill : .none)
                .font(.system(size: 18, weight: .regular))
            Text(tab.label)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
    }
}

// MARK: - DownloadFilter

/// Represents filter/tab selection in the main download list.
enum DownloadFilter: String, CaseIterable, Identifiable {
    case all
    case downloading
    case paused
    case done
    case error

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:         return "All"
        case .downloading: return "Download"
        case .paused:      return "Paused"
        case .done:        return "Done"
        case .error:       return "Error"
        }
    }

    var icon: String {
        switch self {
        case .all:         return "square.grid.2x2"
        case .downloading: return "arrow.down.circle"
        case .paused:      return "pause.circle"
        case .done:        return "checkmark.circle"
        case .error:       return "exclamationmark.circle"
        }
    }

    var matchingStatuses: [DownloadStatus] {
        switch self {
        case .all:         return DownloadStatus.allCases
        case .downloading: return [.running, .pending]
        case .paused:      return [.paused, .interrupted]
        case .done:        return [.completed]
        case .error:       return [.error]
        }
    }
}

// MARK: - FloatingOvalButton

/// A Liquid Glass oval floating button (Edit, Settings).
struct FloatingOvalButton: View {

    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(DS.Typography.callout)
            }
            .foregroundStyle(DS.Colors.label)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .liquidGlass(cornerRadius: DS.Radius.pill)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AddDownloadFAB

/// Circular floating action button for starting a new download.
struct AddDownloadFAB: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DS.Colors.accent)
                    .frame(width: 58, height: 58)
                    .shadow(
                        color: DS.Shadow.fab.color,
                        radius: DS.Shadow.fab.radius,
                        x: DS.Shadow.fab.x,
                        y: DS.Shadow.fab.y
                    )

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.downlySpring, value: false)
    }
}
