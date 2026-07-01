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

// MARK: - Shimmer Progress Bar

/// An indeterminate progress indicator with a horizontally-sweeping
/// gradient animation, used during the initializing state.
struct ShimmerProgressBar: View {

    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                    .fill(DS.Colors.glassBorder)
                    .frame(height: 5)

                // Shimmer sweep
                RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DS.Colors.accent.opacity(0.1),
                                DS.Colors.accent.opacity(0.6),
                                DS.Colors.accent.opacity(0.1),
                            ],
                            startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
                            endPoint: UnitPoint(x: shimmerOffset + 0.5, y: 0.5)
                        )
                    )
                    .frame(height: 5)
            }
        }
        .frame(height: 5)
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 1.5
            }
        }
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
    var isSelected: Bool = false

    @State private var showDetail     = false
    @State private var showUpdateURL  = false

    /// True when the download is running but no bytes have arrived yet.
    private var isInitializing: Bool {
        item.status == .running && item.downloadedSize == 0 && item.totalSize == 0
    }

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

            // Progress bar / Shimmer / Waiting
            if isInitializing {
                ShimmerProgressBar()
                Text("Initializing…")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.labelSec)
                    .transition(.opacity)
            } else if item.status == .pending {
                Text("Waiting…")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.labelSec)
                    .transition(.opacity)
            } else if item.status == .running {
                DownloadProgressBar(progress: item.progressPercent)
                    .transition(.opacity)
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
                HStack {
                    Text(String(format: "%.1f%%", item.progressPercent))
                        .font(DS.Typography.mono)
                        .foregroundStyle(DS.Colors.labelSec)
                    if let etaString = formatETA(item.estimatedSecondsRemaining) {
                        Text("·")
                            .font(DS.Typography.mono)
                            .foregroundStyle(DS.Colors.labelSec)
                        Text(etaString)
                            .font(DS.Typography.mono)
                            .foregroundStyle(DS.Colors.accent)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .liquidGlass(
            cornerRadius: DS.Radius.md,
            tint: DS.Colors.statusColor(for: item.status)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(DS.Colors.accent, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(DS.Colors.selectionHighlight)
                    )
                    .allowsHitTesting(false)
            }
        }
        .opacity(item.status == .paused ? 0.75 : 1.0)
        .animation(.downlySpring, value: item.status.rawValue)
        .animation(.downlySpring, value: isSelected)
        .contentShape(Rectangle())
        // Long press → context menu with card preview
        .contextMenu {
            DownloadContextMenu(
                item: item,
                onUpdateURL: { showUpdateURL = true },
                onShowDetail: { showDetail = true }
            )
        } preview: {
            cardPreview
        }
        // Detail sheet
        .sheet(isPresented: $showDetail) {
            DownloadDetailSheet(
                item: item,
                onPause:      onPause,
                onResume:     onResume,
                onCancel:     onCancel,
                onRetry:      onRetry,
                onUpdateURL:  { showUpdateURL = true }
            )
        }
        // URL update sheet
        .sheet(isPresented: $showUpdateURL) {
            UpdateURLSheet(item: item, onDismiss: {})
        }
    }

    // MARK: - Context menu card preview

    private var cardPreview: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                StatusDot(status: item.status)
                Text(item.fileName)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.label)
                    .lineLimit(1)
                Spacer()
            }
            if item.status == .running {
                DownloadProgressBar(progress: item.progressPercent)
            }
            HStack {
                Text(String(format: "%.1f%%", item.progressPercent))
                    .font(DS.Typography.mono)
                    .foregroundStyle(DS.Colors.labelSec)
                Spacer()
                Text(formatBytes(item.totalSize))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.labelSec)
            }
        }
        .padding(DS.Spacing.md)
        .frame(width: 280)
        .liquidGlass(
            cornerRadius: DS.Radius.md,
            tint: DS.Colors.statusColor(for: item.status)
        )
        .padding(DS.Spacing.md)
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

    /// Returns a human-readable ETA string, or `nil` if `seconds` is unavailable.
    private func formatETA(_ seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        if seconds < 60 {
            return "~\(seconds) sec remaining"
        } else if seconds < 3600 {
            let mins = seconds / 60
            return "~\(mins) min remaining"
        } else {
            let hrs = seconds / 3600
            let mins = (seconds % 3600) / 60
            if mins > 0 {
                return "~\(hrs) hr \(mins) min remaining"
            } else {
                return "~\(hrs) hr remaining"
            }
        }
    }
}

// MARK: - StatusDot

private struct StatusDot: View {
    let status: DownloadStatus

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(DS.Colors.statusColor(for: status))
            .frame(width: 8, height: 8)
            .scaleEffect(status == .pending && isPulsing ? 1.4 : 1.0)
            .opacity(status == .pending && isPulsing ? 0.5 : 1.0)
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
            .onAppear {
                if status == .pending {
                    withAnimation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: status) { _, newStatus in
                if newStatus == .pending {
                    withAnimation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
    }
}
