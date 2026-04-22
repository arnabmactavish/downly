import SwiftUI

// MARK: - SettingsView

/// Modal settings screen (task 9.6).
struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss

    @AppStorage("chunkSizeIndex")          private var chunkSizeIndex         = 1  // 0=1MB 1=4MB 2=8MB
    @AppStorage("maxConcurrentDownloads")  private var maxConcurrentDownloads  = 3
    @AppStorage("allowArbitraryLoads")     private var allowArbitraryLoads    = false
    @AppStorage("liveActivitiesEnabled")   private var liveActivitiesEnabled   = true

    private let chunkSizeOptions: [(label: String, bytes: Int)] = [
        ("1 MB",  1 * 1024 * 1024),
        ("4 MB",  4 * 1024 * 1024),
        ("8 MB",  8 * 1024 * 1024),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.md) {

                        // Section: Download behaviour
                        settingsCard(title: "Downloads") {
                            // Chunk size picker
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Chunk Size")
                                    .font(DS.Typography.callout)
                                Picker("Chunk Size", selection: $chunkSizeIndex) {
                                    ForEach(0..<chunkSizeOptions.count, id: \.self) { i in
                                        Text(chunkSizeOptions[i].label).tag(i)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Text("Larger chunks = fewer connections but more data re-downloaded on failure.")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.labelSec)
                            }

                            Divider()

                            // Max concurrent downloads stepper
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                HStack {
                                    Text("Max Simultaneous Downloads")
                                        .font(DS.Typography.callout)
                                    Spacer()
                                    Stepper(
                                        "\(maxConcurrentDownloads)",
                                        value: $maxConcurrentDownloads,
                                        in: 1...6
                                    )
                                    .fixedSize()
                                }
                                Text("Reducing this helps on slower connections.")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.labelSec)
                            }
                        }

                        // Section: Network
                        settingsCard(title: "Network") {
                            Toggle(isOn: $allowArbitraryLoads) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Allow non-HTTPS downloads")
                                        .font(DS.Typography.callout)
                                    Text("⚠ Your data may be visible to others on the network.")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.warning)
                                }
                            }
                        }

                        // Section: Live Activities
                        settingsCard(title: "Live Activities") {
                            Toggle(isOn: $liveActivitiesEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Show progress on Lock Screen & Dynamic Island")
                                        .font(DS.Typography.callout)
                                    Text("Displays download progress on your Lock Screen and Dynamic Island. May increase battery usage during large downloads.")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.labelSec)
                                }
                            }
                        }

                        settingsCard(title: "Storage") {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Free Space")
                                        .font(DS.Typography.callout)
                                    Text(freeSpaceString())
                                        .font(DS.Typography.mono)
                                        .foregroundStyle(DS.Colors.accent)
                                }
                                Spacer()
                                Image(systemName: "internaldrive")
                                    .font(.system(size: 24))
                                    .foregroundStyle(DS.Colors.labelSec)
                            }
                        }

                        // Section: About
                        settingsCard(title: "About") {
                            HStack {
                                Text("Downly")
                                    .font(DS.Typography.callout)
                                Spacer()
                                Text("Version 1.0")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.labelSec)
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(DS.Typography.callout)
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title.uppercased())
                .font(DS.Typography.captionBold)
                .foregroundStyle(DS.Colors.labelSec)
                .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.sm) {
                content()
            }
            .padding(DS.Spacing.md)
            .liquidGlass(cornerRadius: DS.Radius.md)
        }
    }

    private func freeSpaceString() -> String {
        let checker = DiskSpaceChecker()
        let bytes   = checker.freeBytes()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
