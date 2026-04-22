import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Live Activity Widget


struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadAttributes.self) { context in
            // Lock Screen / Notification Center banner
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.black.opacity(0.7))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.fileName)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text(context.state.formattedSpeed)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f%%", context.state.progressPercent))
                            .font(.caption.bold().monospacedDigit())
                        Text(context.state.formattedETA)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progressPercent, total: 100)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                }

            } compactLeading: {
                Image(systemName: statusIcon(for: context.state.status))
                    .foregroundStyle(.blue)

            } compactTrailing: {
                Text(String(format: "%.0f%%", context.state.progressPercent))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)

            } minimal: {
                ProgressView(value: context.state.progressPercent, total: 100)
                    .progressViewStyle(.circular)
                    .frame(width: 20, height: 20)
                    .tint(.blue)
            }
            .keylineTint(.blue)
        }
    }

    private func statusIcon(for status: DownloadStatus) -> String {
        switch status {
        case .running:     return "arrow.down.circle"
        case .paused:      return "pause.circle"
        case .completed:   return "checkmark.circle"
        case .error:       return "exclamationmark.circle"
        default:           return "clock.circle"
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {

    let context: ActivityViewContext<DownloadAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, isActive: context.state.status == .running)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.fileName)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                ProgressView(value: context.state.progressPercent, total: 100)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                HStack {
                    Text(String(format: "%.1f%%", context.state.progressPercent))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(context.state.formattedSpeed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("ETA: \(context.state.formattedETA)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }
}
