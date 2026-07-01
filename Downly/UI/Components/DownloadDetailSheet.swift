import SwiftUI
import Charts

// MARK: - DownloadDetailSheet

/// Bottom sheet with comprehensive download details, speed graph, and contextual actions.
/// Presents at `.medium` (overview) and `.large` (full details + speed graph).
struct DownloadDetailSheet: View {

    // MARK: - Input

    let item: DownloadItem
    let onPause:     () -> Void
    let onResume:    () -> Void
    let onCancel:    () -> Void
    let onRetry:     () -> Void
    let onUpdateURL: () -> Void

    // MARK: - Dependencies

    @EnvironmentObject private var queueManager: DownloadQueueManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var selectedDetent: PresentationDetent = .medium
    @State private var showURLExpanded = false
    @State private var showConfetti = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                    // Progress ring + title
                    progressHeader

                    Divider()
                        .padding(.horizontal, DS.Spacing.md)

                    // File metadata
                    metadataSection

                    // URL section
                    urlSection

                    // Error details (error state)
                    if item.status == .error, let error = item.errorMessage {
                        errorSection(message: error)
                    }

                    // Speed graph (running/paused with history)
                    if selectedDetent == .large || UIScreen.main.bounds.height > 700 {
                        if item.status == .running || (item.status == .paused && !SpeedHistoryStore.shared.history(for: item.id).samples.isEmpty) {
                            speedGraphSection
                        }

                        // Chunk breakdown
                        if !item.chunks.isEmpty {
                            chunkBreakdownSection
                        }

                        // File location (completed)
                        if item.status == .completed {
                            fileLocationSection
                        }
                    }

                    Spacer(minLength: DS.Spacing.xxl)
                }
                .padding(.top, DS.Spacing.md)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(item.status.displayName)
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.statusColor(for: item.status))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(DS.Radius.lg)
        .onAppear {
            // Confetti for completed download on first open
            if item.status == .completed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.downlySpring) {
                        showConfetti = true
                    }
                }
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Circular progress ring
            CircularProgressRing(
                progress: item.progressPercent / 100,
                status: item.status,
                showConfetti: showConfetti
            )
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(item.fileName)
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.label)
                    .lineLimit(2)

                if item.status == .running, let speed = speedBytesPerSecond {
                    Text(ByteCountFormatter.string(fromByteCount: speed, countStyle: .file) + "/s")
                        .font(DS.Typography.mono)
                        .foregroundStyle(DS.Colors.accent)
                        .contentTransition(.numericText())
                        .animation(.downlySpring, value: speed)
                }

                if item.totalSize > 0 {
                    Text(String(format: "%.1f%%", item.progressPercent))
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.statusColor(for: item.status))
                        .contentTransition(.numericText())
                }
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            sectionHeader("Details")

            infoGrid
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    private var infoGrid: some View {
        VStack(spacing: DS.Spacing.xs) {
            if item.downloadedSize > 0 {
                infoRow(
                    label: "Downloaded",
                    value: ByteCountFormatter.string(fromByteCount: item.downloadedSize, countStyle: .file)
                )
            }
            if item.totalSize > 0 {
                infoRow(
                    label: "Total Size",
                    value: ByteCountFormatter.string(fromByteCount: item.totalSize, countStyle: .file)
                )
            }
            if item.remainingSize > 0 && item.status == .running {
                infoRow(
                    label: "Remaining",
                    value: ByteCountFormatter.string(fromByteCount: item.remainingSize, countStyle: .file)
                )
            }
            if let eta = item.estimatedSecondsRemaining, eta > 0, item.status == .running {
                infoRow(label: "ETA", value: formatETA(eta))
            }
            infoRow(label: "Added", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
            if item.status != .pending {
                infoRow(label: "Updated", value: item.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            if !item.chunks.isEmpty {
                infoRow(label: "Chunks", value: "\(item.chunks.filter { $0.status == .completed }.count) / \(item.chunks.count)")
            }
        }
        .padding(DS.Spacing.sm)
        .liquidGlass(cornerRadius: DS.Radius.sm)
    }

    // MARK: - URL Section

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            sectionHeader("URL")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(item.url)
                    .font(DS.Typography.mono)
                    .foregroundStyle(DS.Colors.labelSec)
                    .lineLimit(showURLExpanded ? nil : 2)
                    .onTapGesture { showURLExpanded.toggle() }

                if item.url.count > 80 {
                    Button(showURLExpanded ? "Show Less" : "Show More") {
                        withAnimation(.downlySpring) { showURLExpanded.toggle() }
                    }
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.accent)
                    .buttonStyle(.plain)
                }

                HStack {
                    Button {
                        UIPasteboard.general.string = item.url
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("Copy", systemImage: "doc.on.clipboard")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Spacing.sm)
            .liquidGlass(cornerRadius: DS.Radius.sm)
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Error Section

    private func errorSection(message: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            sectionHeader("Error Details")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Label("Error", systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Typography.captionBold)
                    .foregroundStyle(DS.Colors.error)

                Text(message)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.label)

                HStack {
                    Button {
                        UIPasteboard.general.string = message
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("Copy Error", systemImage: "doc.on.clipboard")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.error)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Spacing.sm)
            .liquidGlass(cornerRadius: DS.Radius.sm, tint: DS.Colors.error)
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Speed Graph

    private var speedGraphSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            sectionHeader("Speed History")

            SpeedGraphView(
                samples: SpeedHistoryStore.shared.history(for: item.id).samples,
                accentColor: DS.Colors.statusColor(for: item.status),
                isPaused: item.status == .paused
            )
            .frame(height: 120)
            .padding(DS.Spacing.sm)
            .liquidGlass(cornerRadius: DS.Radius.sm)
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Chunk Breakdown

    private var chunkBreakdownSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            sectionHeader("Chunks (\(item.chunks.count) total)")

            LazyVStack(spacing: 4) {
                ForEach(item.chunks.sorted(by: { $0.index < $1.index }), id: \.index) { chunk in
                    ChunkRowView(chunk: chunk)
                }
            }
            .padding(DS.Spacing.xs)
            .liquidGlass(cornerRadius: DS.Radius.sm)
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - File Location

    private var fileLocationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            sectionHeader("File Location")

            HStack {
                Label("On My iPhone → Downly → \(item.fileName)", systemImage: "folder.fill")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.labelSec)
                Spacer()
            }
            .padding(DS.Spacing.sm)
            .liquidGlass(cornerRadius: DS.Radius.sm, tint: DS.Colors.success)
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            switch item.status {
            case .running:
                actionButton(title: "Pause", icon: "pause.fill", tint: DS.Colors.accent) {
                    onPause()
                    dismiss()
                }
                actionButton(title: "Cancel", icon: "xmark", tint: DS.Colors.error, role: .destructive) {
                    onCancel()
                    dismiss()
                }

            case .paused, .interrupted:
                actionButton(title: "Resume", icon: "play.fill", tint: DS.Colors.accent) {
                    onResume()
                    dismiss()
                }
                actionButton(title: "Update URL", icon: "link.badge.plus", tint: DS.Colors.warning) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onUpdateURL() }
                }
                actionButton(title: "Cancel", icon: "xmark", tint: DS.Colors.error, role: .destructive) {
                    onCancel()
                    dismiss()
                }

            case .error:
                actionButton(title: "Retry", icon: "arrow.clockwise", tint: DS.Colors.warning) {
                    onRetry()
                    dismiss()
                }
                actionButton(title: "Update URL", icon: "link.badge.plus", tint: DS.Colors.accent) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onUpdateURL() }
                }
                actionButton(title: "Delete", icon: "trash", tint: DS.Colors.error, role: .destructive) {
                    onCancel()
                    dismiss()
                }

            case .completed:
                if let url = fileURL {
                    ShareLink(item: url, message: Text(item.fileName)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(DS.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                }

            case .pending:
                actionButton(title: "Cancel", icon: "xmark", tint: DS.Colors.error, role: .destructive) {
                    onCancel()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Helpers

    private var speedBytesPerSecond: Int64? {
        item.speedBytesPerSecond > 0 ? item.speedBytesPerSecond : nil
    }

    private var fileURL: URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(item.fileName)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    private func formatETA(_ seconds: Int) -> String {
        if seconds < 60 { return "~\(seconds) sec" }
        if seconds < 3600 { return "~\(seconds / 60) min" }
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        return mins > 0 ? "~\(hrs)h \(mins)m" : "~\(hrs)h"
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DS.Typography.captionBold)
            .foregroundStyle(DS.Colors.labelSec)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.labelSec)
            Spacer()
            Text(value)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.label)
                .multilineTextAlignment(.trailing)
        }
    }

    private func actionButton(
        title: String,
        icon: String,
        tint: Color,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(DS.Typography.captionBold)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CircularProgressRing

/// An animated circular progress ring with gradient stroke.
struct CircularProgressRing: View {

    let progress: Double     // 0.0 – 1.0
    let status: DownloadStatus
    let showConfetti: Bool

    @State private var animatedProgress: Double = 0

    private var accentColor: Color { DS.Colors.statusColor(for: status) }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(DS.Colors.glassBorder, lineWidth: 6)

            // Fill
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [accentColor.opacity(0.5), accentColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)

            // Center icon or percentage
            if status == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accentColor)
                    .scaleEffect(showConfetti ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showConfetti)
            } else if status == .error {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accentColor)
            } else if status == .paused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accentColor)
            } else {
                Text(String(format: "%.0f", animatedProgress * 100) + "%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText())
            }

            // Celebration particles for completed state
            if showConfetti && status == .completed {
                ForEach(0..<8, id: \.self) { i in
                    ConfettiDot(index: i, accentColor: accentColor)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - ConfettiDot

private struct ConfettiDot: View {
    let index: Int
    let accentColor: Color

    @State private var isAnimating = false

    private let angle: Double
    private let color: Color
    private let size: CGFloat

    init(index: Int, accentColor: Color) {
        self.index = index
        self.accentColor = accentColor
        self.angle = Double(index) * 45.0
        let colors: [Color] = [accentColor, .yellow, .pink, .green, accentColor.opacity(0.7), .orange, .purple, .cyan]
        self.color = colors[index % colors.count]
        self.size = CGFloat.random(in: 4...7)
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(
                x: isAnimating ? cos(angle * .pi / 180) * 50 : 0,
                y: isAnimating ? sin(angle * .pi / 180) * 50 : 0
            )
            .opacity(isAnimating ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(Double(index) * 0.05)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - SpeedGraphView

/// Swift Charts area graph showing speed history over time.
struct SpeedGraphView: View {

    let samples: [SpeedSample]
    let accentColor: Color
    let isPaused: Bool

    var body: some View {
        if samples.isEmpty {
            HStack {
                Spacer()
                Text(isPaused ? "Paused — no speed history" : "Waiting for data…")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.labelSec)
                Spacer()
            }
        } else {
            Chart(samples) { sample in
                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Speed", sample.bytesPerSecond)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor.opacity(0.5), accentColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Speed", sample.bytesPerSecond)
                )
                .foregroundStyle(accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    if let bytes = value.as(Int64.self) {
                        AxisValueLabel {
                            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + "/s")
                                .font(DS.Typography.mono)
                                .foregroundStyle(DS.Colors.labelSec)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...(Int64(Double(peakSpeed) * 1.2) + 1))

            .overlay(alignment: .topTrailing) {
                if isPaused {
                    Text("Paused")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.paused)
                        .padding(DS.Spacing.xxs)
                        .background(DS.Colors.glassFill)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(DS.Spacing.xs)
                }
            }
        }
    }

    private var peakSpeed: Int64 {
        samples.map(\.bytesPerSecond).max() ?? 0
    }
}

// MARK: - ChunkRowView

private struct ChunkRowView: View {
    let chunk: ChunkRecord

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Status indicator
            Circle()
                .fill(chunkColor)
                .frame(width: 6, height: 6)

            Text("Chunk \(chunk.index + 1)")
                .font(DS.Typography.mono)
                .foregroundStyle(DS.Colors.labelSec)

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: chunk.byteCount, countStyle: .file))
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.labelSec)

            Text(chunk.status.displayName)
                .font(DS.Typography.captionBold)
                .foregroundStyle(chunkColor)
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, 3)
    }

    private var chunkColor: Color {
        switch chunk.status {
        case .completed:   return DS.Colors.success
        case .downloading: return DS.Colors.accent
        case .failed:      return DS.Colors.error
        case .pending:     return DS.Colors.labelSec
        }
    }
}

// MARK: - ChunkStatus display

private extension ChunkStatus {
    var displayName: String {
        switch self {
        case .pending:     return "Pending"
        case .downloading: return "Downloading"
        case .completed:   return "Done"
        case .failed:      return "Failed"
        }
    }
}
