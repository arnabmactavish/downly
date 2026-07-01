import SwiftUI

// MARK: - UpdateURLSheet

/// A sheet allowing users to supply a replacement URL for a paused or errored download.
/// Performs HEAD validation and supports "Start Fresh" when the server is incompatible.
struct UpdateURLSheet: View {

    // MARK: - Input

    let item: DownloadItem
    let onDismiss: () -> Void

    // MARK: - Dependencies

    @EnvironmentObject private var queueManager: DownloadQueueManager

    // MARK: - State

    @Environment(\.dismiss) private var dismiss

    @State private var urlText: String = ""
    @State private var validationState: ValidationState = .idle
    @State private var showStartFreshConfirm = false
    @State private var pendingNewURL: URL?

    // MARK: - Types

    private enum ValidationState: Equatable {
        case idle
        case validating
        case success(message: String)
        case incompatibleNoRanges
        case sizeMismatch(serverLength: Int64, downloadedBytes: Int64)
        case failed(message: String)

        var isLoading: Bool { self == .validating }

        static func == (lhs: ValidationState, rhs: ValidationState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.validating, .validating),
                 (.incompatibleNoRanges, .incompatibleNoRanges):
                return true
            case (.success(let a), .success(let b)): return a == b
            case (.failed(let a), .failed(let b)):   return a == b
            case (.sizeMismatch(let s1, let d1), .sizeMismatch(let s2, let d2)):
                return s1 == s2 && d1 == d2
            default:
                return false
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                    // Context info
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(item.fileName)
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Colors.label)

                        Text("Current URL")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.labelSec)

                        Text(item.url)
                            .font(DS.Typography.mono)
                            .foregroundStyle(DS.Colors.labelSec)
                            .lineLimit(3)
                    }
                    .padding(DS.Spacing.md)
                    .liquidGlass(cornerRadius: DS.Radius.sm)

                    // Progress info
                    HStack {
                        Label(
                            ByteCountFormatter.string(
                                fromByteCount: item.downloadedSize, countStyle: .file
                            ) + " already downloaded",
                            systemImage: "arrow.down.circle.fill"
                        )
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.accent)
                    }

                    // New URL input
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("New URL")
                            .font(DS.Typography.captionBold)
                            .foregroundStyle(DS.Colors.labelSec)

                        TextField("https://", text: $urlText)
                            .font(DS.Typography.body)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(DS.Spacing.sm)
                            .background(DS.Colors.glassFill)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .stroke(DS.Colors.glassBorder, lineWidth: 0.5)
                            )
                    }

                    // Paste from clipboard shortcut
                    if let clip = UIPasteboard.general.string,
                       URL(string: clip)?.scheme?.hasPrefix("http") == true,
                       clip != urlText {
                        Button {
                            urlText = clip
                            validationState = .idle
                        } label: {
                            Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    // Validation feedback
                    validationFeedback

                    // Primary action
                    Button {
                        Task { await validate() }
                    } label: {
                        HStack {
                            if validationState.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(validationState.isLoading ? "Validating…" : "Validate & Update")
                                .font(DS.Typography.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.md)
                        .background(
                            canValidate
                                ? DS.Colors.accent
                                : DS.Colors.accent.opacity(0.4)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canValidate)
                    .animation(.downlySpring, value: validationState)
                }
                .padding(DS.Spacing.md)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Update URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.labelSec)
                }
            }
            .onAppear {
                // Auto-populate from clipboard if it looks like a URL
                if let clip = UIPasteboard.general.string,
                   URL(string: clip)?.scheme?.hasPrefix("http") == true {
                    urlText = clip
                }
            }
        }
        .confirmationDialog(
            "Start Fresh?",
            isPresented: $showStartFreshConfirm,
            titleVisibility: .visible
        ) {
            Button("Start Fresh", role: .destructive) {
                if let url = pendingNewURL {
                    Task { await applyUpdate(newURL: url, resetProgress: true) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The new URL's file is smaller than what's already been downloaded. Starting fresh will reset all progress.")
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var validationFeedback: some View {
        switch validationState {
        case .idle:
            EmptyView()

        case .validating:
            EmptyView()

        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.success)
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .incompatibleNoRanges:
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Label("Server doesn't support resume", systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Typography.captionBold)
                    .foregroundStyle(DS.Colors.warning)
                Text("This server doesn't support partial downloads. You can start fresh from 0%.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.labelSec)
                Button("Start Fresh") {
                    if let url = URL(string: urlText) {
                        pendingNewURL = url
                        showStartFreshConfirm = true
                    }
                }
                .font(DS.Typography.captionBold)
                .foregroundStyle(DS.Colors.warning)
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.sm)
            .liquidGlass(cornerRadius: DS.Radius.sm, tint: DS.Colors.warning)
            .transition(.opacity)

        case .sizeMismatch(let serverLength, let downloadedBytes):
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Label("File size mismatch", systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Typography.captionBold)
                    .foregroundStyle(DS.Colors.warning)
                Text(
                    "Server file (\(ByteCountFormatter.string(fromByteCount: serverLength, countStyle: .file)))" +
                    " is smaller than downloaded data (\(ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)))."
                )
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.labelSec)
                Button("Start Fresh") {
                    if let url = URL(string: urlText) {
                        pendingNewURL = url
                        showStartFreshConfirm = true
                    }
                }
                .font(DS.Typography.captionBold)
                .foregroundStyle(DS.Colors.warning)
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.sm)
            .liquidGlass(cornerRadius: DS.Radius.sm, tint: DS.Colors.warning)
            .transition(.opacity)

        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.error)
                .transition(.opacity)
        }
    }

    // MARK: - Logic

    private var canValidate: Bool {
        !urlText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !validationState.isLoading &&
        URL(string: urlText.trimmingCharacters(in: .whitespaces)) != nil
    }

    private func validate() async {
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard let newURL = URL(string: trimmed) else {
            validationState = .failed(message: "Invalid URL")
            return
        }

        withAnimation(.downlySpring) {
            validationState = .validating
        }

        do {
            try await queueManager.updateURL(id: item.id, newURL: newURL)
            withAnimation(.downlySpring) {
                validationState = .success(message: "URL updated successfully. Resume when ready.")
            }
            // Brief delay so user sees success before dismiss
            try? await Task.sleep(for: .seconds(1.0))
            dismiss()
            onDismiss()
        } catch DownloadQueueError.urlNotCompatible {
            withAnimation(.downlySpring) {
                validationState = .incompatibleNoRanges
            }
        } catch DownloadQueueError.contentLengthMismatch(let serverLength, let downloadedBytes) {
            withAnimation(.downlySpring) {
                pendingNewURL = newURL
                validationState = .sizeMismatch(
                    serverLength: serverLength,
                    downloadedBytes: downloadedBytes
                )
            }
        } catch {
            withAnimation(.downlySpring) {
                validationState = .failed(message: error.localizedDescription)
            }
        }
    }

    private func applyUpdate(newURL: URL, resetProgress: Bool) async {
        do {
            try await queueManager.updateURL(id: item.id, newURL: newURL, resetProgress: resetProgress)
            dismiss()
            onDismiss()
        } catch {
            withAnimation(.downlySpring) {
                validationState = .failed(message: error.localizedDescription)
            }
        }
    }
}
