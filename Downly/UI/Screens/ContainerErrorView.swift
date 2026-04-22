import SwiftUI

// MARK: - ContainerErrorView

/// Displayed as a full-screen overlay when SwiftData's `ModelContainer`
/// cannot be created in a release build.
///
/// Storage unavailability is unrecoverable at runtime — the only meaningful
/// user action is to restart the app after the OS resolves the issue.
struct ContainerErrorView: View {

    let error: Error

    // Subtle pulsing animation for the warning icon.
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Full-screen dark backdrop
            Color(uiColor: .systemBackground)
                .opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {

                // MARK: Icon
                ZStack {
                    Circle()
                        .fill(DS.Colors.error.opacity(0.15))
                        .frame(width: 96, height: 96)
                        .scaleEffect(isPulsing ? 1.08 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: isPulsing
                        )

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(DS.Colors.error)
                }

                // MARK: Text
                VStack(spacing: DS.Spacing.xs) {
                    Text("Storage Unavailable")
                        .font(DS.Typography.title)
                        .foregroundStyle(DS.Colors.label)
                        .multilineTextAlignment(.center)

                    Text("Downly couldn't open its database. This is usually temporary.")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.labelSec)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }

                // MARK: Error detail (collapsed by default)
                DisclosureGroup {
                    Text(error.localizedDescription)
                        .font(DS.Typography.mono)
                        .foregroundStyle(DS.Colors.labelSec)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DS.Spacing.xxs)
                } label: {
                    Text("Technical details")
                        .font(DS.Typography.captionBold)
                        .foregroundStyle(DS.Colors.labelSec)
                }
                .padding(.horizontal, DS.Spacing.xl)

                // MARK: Restart button
                Button {
                    // Storage errors are unrecoverable at runtime;
                    // terminating forces the OS to re-launch cleanly.
                    exit(0)
                } label: {
                    Label("Restart App", systemImage: "arrow.clockwise")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.xl)
                        .background(DS.Colors.error, in: Capsule())
                }
                .padding(.top, DS.Spacing.xs)
            }
            .padding(DS.Spacing.lg)
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ContainerErrorView(
        error: ContainerError.appGroupUnavailable(id: "group.com.axoman.downly")
    )
}
#endif
