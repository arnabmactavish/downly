import SwiftUI

// MARK: - Animated Progress Bar

struct DownloadProgressBar: View {

    var progress: Double  // 0–100

    private var fraction: Double { min(progress / 100.0, 1.0) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                    .fill(DS.Colors.glassBorder)
                    .frame(height: 5)

                // Fill
                RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                    .fill(DS.Colors.accent)
                    .frame(width: max(geo.size.width * fraction, 6), height: 5)
                    .animation(.downlySpring, value: fraction)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - DownloadItemCard

/// A Liquid Glass card representing one download item.
struct DownloadItemCard: View {

    let item: DownloadItem
    let onPause:  () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let onRetry:  () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {

            // Header row
            HStack(alignment: .center) {
                StatusDot(status: item.status)

                Text(item.fileName)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.label)
                    .lineLimit(1)

                Spacer()

                // Action buttons
                actionButtons
            }

            // Progress bar (not shown for terminal/paused states without ongoing bytes)
            if item.status == .running || item.status == .pending {
                DownloadProgressBar(progress: item.progressPercent)
            }

            // Stats row
            HStack {
                statsLabel(
                    icon: "arrow.down.circle",
                    text: formatBytes(item.downloadedSize)
                )

                Spacer()

                if item.totalSize > 0 {
                    statsLabel(
                        icon: "doc",
                        text: formatBytes(item.totalSize)
                    )
                }

                Spacer()

                if item.status == .running, let speed = currentSpeed {
                    speedLabel(speed)
                }
                if item.status == .paused {
                    Text("Paused")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.paused)
                }

                if item.status == .completed {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(DS.Typography.captionBold)
                        .foregroundStyle(DS.Colors.success)
                }
                if item.status == .error {
                    Label(item.errorMessage ?? "Error", systemImage: "exclamationmark.circle")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.error)
                        .lineLimit(1)
                }
            }

            // Progress percentage (running only)
            if item.status == .running, item.totalSize > 0 {
                Text(String(format: "%.1f%% · %@ remaining", item.progressPercent, formatBytes(item.remainingSize)))
                    .font(DS.Typography.mono)
                    .foregroundStyle(DS.Colors.labelSec)
            }
        }
        .padding(DS.Spacing.md)
        .liquidGlass(
            cornerRadius: DS.Radius.md,
            tint: DS.Colors.statusColor(for: item.status)
        )
        .opacity(item.status == .paused ? 0.75 : 1.0)
        .animation(.downlySpring, value: item.status.rawValue)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: DS.Spacing.xs) {
            switch item.status {
            case .running:
                circleButton(icon: "pause.fill", tint: DS.Colors.accent,  action: onPause)
                circleButton(icon: "xmark",      tint: DS.Colors.error,   action: onCancel)
            case .paused, .interrupted:
                circleButton(icon: "play.fill",  tint: DS.Colors.accent,  action: onResume)
                circleButton(icon: "xmark",      tint: DS.Colors.error,   action: onCancel)
            case .error:
                circleButton(icon: "arrow.clockwise", tint: DS.Colors.warning, action: onRetry)
                circleButton(icon: "xmark",           tint: DS.Colors.error,   action: onCancel)
            case .pending:
                circleButton(icon: "xmark", tint: DS.Colors.error, action: onCancel)
            case .completed:
                EmptyView()
            }
        }
    }

    private func circleButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(tint)
                .background(tint.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func statsLabel(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.labelSec)
    }

    private func speedLabel(_ bps: Int64) -> some View {
        Text(ByteCountFormatter.string(fromByteCount: bps, countStyle: .file) + "/s")
            .font(DS.Typography.mono)
            .foregroundStyle(DS.Colors.accent)
    }

    // Speed is persisted to SwiftData via PersistenceThrottle on every progress flush.
    // Returns nil when speed is 0 to avoid showing "0 bytes/s" at rest.
    private var currentSpeed: Int64? {
        item.speedBytesPerSecond > 0 ? item.speedBytesPerSecond : nil
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - StatusDot

private struct StatusDot: View {
    let status: DownloadStatus

    var body: some View {
        Circle()
            .fill(DS.Colors.statusColor(for: status))
            .frame(width: 8, height: 8)
            .overlay {
                if status == .running {
                    Circle()
                        .fill(DS.Colors.accent.opacity(0.3))
                        .scaleEffect(1.6)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: status.rawValue
                        )
                }
            }
    }
}
