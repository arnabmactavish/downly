import SwiftUI

// MARK: - AddDownloadSheet

/// Modal sheet for adding a new download URL.
///
/// Clipboard URL is pre-populated on appearance (tasks 9.4, 9.5).
struct AddDownloadSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onStart: (String, String) -> Void

    @State private var urlText             = ""
    @State private var fileName            = ""
    @State private var fileNameHint        = ""   // URL-derived hint shown as placeholder
    @State private var isURLInvalid        = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                    // Header
                    Text("New Download")
                        .font(DS.Typography.largeTitle)
                        .padding(.top, DS.Spacing.lg)

                    // URL field
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Label("URL", systemImage: "link")
                            .font(DS.Typography.captionBold)
                            .foregroundStyle(DS.Colors.labelSec)

                        TextField("https://example.com/file.zip", text: $urlText)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(DS.Typography.body)
                            .padding(DS.Spacing.md)
                            .liquidGlass(cornerRadius: DS.Radius.sm)
                            .overlay {
                                if isURLInvalid {
                                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                        .stroke(DS.Colors.error, lineWidth: 1)
                                }
                            }
                            .onChange(of: urlText) { _, newURL in
                                isURLInvalid = false
                                deriveFileName(from: newURL)
                            }
                    }

                    // File name field
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Label("File Name (optional)", systemImage: "doc")
                            .font(DS.Typography.captionBold)
                            .foregroundStyle(DS.Colors.labelSec)

                        TextField(
                            fileNameHint.isEmpty ? "file.zip" : fileNameHint,
                            text: $fileName
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(DS.Typography.body)
                        .padding(DS.Spacing.md)
                        .liquidGlass(cornerRadius: DS.Radius.sm)
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: DS.Spacing.sm) {
                        Button {
                            startDownload()
                        } label: {
                            Text("Start Download")
                                .font(DS.Typography.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(DS.Spacing.md)
                                .background(DS.Colors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Colors.labelSec)
                                .frame(maxWidth: .infinity)
                                .padding(DS.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
        }
        .onAppear {
            // Task 9.5 — pre-populate from clipboard if it contains a URL
            if let clipURL = UIPasteboard.general.url {
                urlText = clipURL.absoluteString
                deriveFileName(from: clipURL.absoluteString)
            }
        }
    }

    // MARK: - Actions

    private func startDownload() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else {
            withSpringAnimation { isURLInvalid = true }
            return
        }
        // Priority: user-typed name → URL-derived hint → "download"
        let name = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = name.isEmpty
            ? (fileNameHint.isEmpty ? "download" : fileNameHint)
            : name
        onStart(trimmed, effectiveName)
        dismiss()
    }

    /// Updates the greyed-out placeholder hint from the URL without touching
    /// the actual `fileName` field, so a server-side Content-Disposition name
    /// can still win inside `executeDownload`.
    private func deriveFileName(from urlString: String) {
        guard let url = URL(string: urlString),
              !url.lastPathComponent.isEmpty,
              url.lastPathComponent != "/"
        else {
            fileNameHint = ""
            return
        }
        fileNameHint = url.lastPathComponent
    }
}
