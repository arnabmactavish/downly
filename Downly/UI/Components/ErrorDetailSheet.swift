import SwiftUI
import UIKit

/// A sheet view that displays full error details for a failed download,
/// with options to copy or share the error report.
struct ErrorDetailSheet: View {

    // MARK: - Inputs

    let fileName: String
    let url: String
    let errorMessage: String
    let errorDate: Date

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedConfirmation = false

    // MARK: - Computed

    private var formattedReport: String {
        """
        Downly Error Report
        ───────────────────
        File: \(fileName)
        URL: \(url)
        Time: \(errorDate.formatted(date: .abbreviated, time: .standard))

        Error:
        \(errorMessage)
        """
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {

                    // Error icon header
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(DS.Colors.error)
                            .symbolRenderingMode(.hierarchical)
                        Spacer()
                    }
                    .padding(.top, DS.Spacing.md)

                    // File info section
                    detailCard(title: "FILE") {
                        detailRow(label: "Name", value: fileName)
                        Divider()
                        detailRow(label: "URL", value: url)
                        Divider()
                        detailRow(
                            label: "Time",
                            value: errorDate.formatted(
                                date: .abbreviated,
                                time: .standard
                            )
                        )
                    }

                    // Error message section
                    detailCard(title: "ERROR") {
                        Text(errorMessage)
                            .font(DS.Typography.mono)
                            .foregroundStyle(DS.Colors.error)
                            .textSelection(.enabled)
                    }

                    // Action buttons
                    HStack(spacing: DS.Spacing.sm) {
                        // Copy button
                        Button {
                            UIPasteboard.general.string = formattedReport
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            withSpringAnimation {
                                showCopiedConfirmation = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withSpringAnimation {
                                    showCopiedConfirmation = false
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: showCopiedConfirmation
                                      ? "checkmark"
                                      : "doc.on.doc")
                                Text(showCopiedConfirmation ? "Copied!" : "Copy")
                            }
                            .font(DS.Typography.callout)
                            .frame(maxWidth: .infinity)
                            .padding(DS.Spacing.sm)
                            .foregroundStyle(showCopiedConfirmation
                                ? DS.Colors.success
                                : DS.Colors.accent)
                        }
                        .liquidGlass(cornerRadius: DS.Radius.sm)

                        // Share button
                        ShareLink(item: formattedReport) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(DS.Typography.callout)
                            .frame(maxWidth: .infinity)
                            .padding(DS.Spacing.sm)
                            .foregroundStyle(DS.Colors.accent)
                        }
                        .liquidGlass(cornerRadius: DS.Radius.sm)
                    }
                }
                .padding(DS.Spacing.md)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Error Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.Colors.labelSec)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func detailCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.captionBold)
                .foregroundStyle(DS.Colors.labelSec)
                .padding(.leading, DS.Spacing.xs)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                content()
            }
            .padding(DS.Spacing.md)
            .liquidGlass(cornerRadius: DS.Radius.sm)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.labelSec)
            Text(value)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.label)
                .textSelection(.enabled)
        }
    }
}
