import SwiftUI

// MARK: - Design System

/// Centralised design tokens for Downly.
///
/// All colours, typography, spacing and animation values are defined here.
/// Never use hard-coded values in views — reference these constants instead.
enum DS {

    // MARK: - Colour Palette

    enum Colors {
        /// Primary accent — vivid electric blue
        static let accent      = Color(hue: 0.60, saturation: 0.85, brightness: 1.0)
        /// Success green
        static let success     = Color(hue: 0.36, saturation: 0.72, brightness: 0.78)
        /// Destructive / error red-orange
        static let error       = Color(hue: 0.03, saturation: 0.80, brightness: 0.90)
        /// Warning amber
        static let warning     = Color(hue: 0.10, saturation: 0.85, brightness: 0.95)
        /// Neutral paused grey-blue
        static let paused      = Color(hue: 0.58, saturation: 0.20, brightness: 0.65)

        /// Primary label (adapts to light/dark)
        static let label       = Color.primary
        /// Secondary label
        static let labelSec    = Color.secondary

        /// Glass card fill (semi-transparent white/dark)
        static let glassFill   = Color.white.opacity(0.08)
        /// Glass border
        static let glassBorder = Color.white.opacity(0.15)

        /// Page / list background
        static let background  = Color(uiColor: .systemBackground)

        /// Selection highlight — tinted accent at low opacity for selected cards
        static let selectionHighlight = Color(hue: 0.60, saturation: 0.85, brightness: 1.0).opacity(0.15)

        /// Subtle tint for context menu / detail sheet backgrounds
        static let sheetBackground = Color(uiColor: .secondarySystemGroupedBackground)

        // Status-driven colours
        static func statusColor(for status: DownloadStatus) -> Color {
            switch status {
            case .running:     return accent
            case .paused:      return paused
            case .completed:   return success
            case .error:       return error
            case .pending:     return labelSec
            case .interrupted: return warning
            }
        }
    }

    // MARK: - Typography (SF Pro)

    enum Typography {
        static let largeTitle  = Font.system(.largeTitle,  design: .rounded, weight: .bold)
        static let title       = Font.system(.title2,      design: .rounded, weight: .semibold)
        static let headline    = Font.system(.headline,    design: .default, weight: .semibold)
        static let body        = Font.system(.body,        design: .default, weight: .regular)
        static let callout     = Font.system(.callout,     design: .default, weight: .medium)
        static let caption     = Font.system(.caption,     design: .default, weight: .regular)
        static let captionBold = Font.system(.caption,     design: .default, weight: .semibold)
        static let mono        = Font.system(.caption,     design: .monospaced, weight: .medium)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radii

    enum Radius {
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 20
        static let lg:  CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows

    enum Shadow {
        static let card = (color: Color.black.opacity(0.25), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4))
        static let fab  = (color: Color.black.opacity(0.35), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(6))
    }
}

// MARK: - Spring Animation Helper

extension Animation {
    /// Standard spring used for all state-transition animations in Downly.
    static let downlySpring = Animation.spring(
        response: 0.45,
        dampingFraction: 0.72,
        blendDuration: 0
    )
}

/// Runs `body` inside a standard Downly spring animation.
@discardableResult
func withSpringAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    try withAnimation(.downlySpring, body)
}

// MARK: - LiquidGlass ViewModifier

/// Applies the Liquid Glass aesthetic to any view:
/// ultra-thin material blur + semi-transparent fill + stroke + rounded corners.
struct LiquidGlassBackground: ViewModifier {

    var cornerRadius: CGFloat
    var tint: Color
    var showFill: Bool

    init(cornerRadius: CGFloat = DS.Radius.md, tint: Color = .clear, showFill: Bool = true) {
        self.cornerRadius = cornerRadius
        self.tint         = tint
        self.showFill     = showFill
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if showFill {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(DS.Colors.glassFill)
                        }
                    }
                    .overlay {
                        if tint != .clear {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint.opacity(0.08))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(DS.Colors.glassBorder, lineWidth: 0.5)
                    }
                    .shadow(
                        color: DS.Shadow.card.color,
                        radius: DS.Shadow.card.radius,
                        x: DS.Shadow.card.x,
                        y: DS.Shadow.card.y
                    )
            }
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = DS.Radius.md,
        tint: Color = .clear,
        showFill: Bool = true
    ) -> some View {
        modifier(LiquidGlassBackground(cornerRadius: cornerRadius, tint: tint, showFill: showFill))
    }
}
