import SwiftUI

// MARK: - DownloadContextMenu

/// Builds state-appropriate context menu items for a download card.
/// Attach via `.contextMenu(menuItems:)` or `.contextMenu(menuItems:preview:)`.
struct DownloadContextMenu: View {

    // MARK: - Input

    let item: DownloadItem
    let onUpdateURL: () -> Void
    let onShowDetail: () -> Void

    // MARK: - Dependencies

    @EnvironmentObject private var queueManager: DownloadQueueManager
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        Group {
            // State-specific primary actions
            switch item.status {
            case .running:
                Button {
                    Task { await queueManager.pauseDownload(id: item.id) }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }

                Button(role: .destructive) {
                    queueManager.cancelDownload(id: item.id)
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }

            case .paused, .interrupted:
                Button {
                    queueManager.resumeDownload(id: item.id)
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }

                Button {
                    onUpdateURL()
                } label: {
                    Label("Update URL", systemImage: "link.badge.plus")
                }

                Button(role: .destructive) {
                    queueManager.cancelDownload(id: item.id)
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }

            case .error:
                Button {
                    queueManager.resumeDownload(id: item.id)
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }

                Button {
                    onUpdateURL()
                } label: {
                    Label("Update URL", systemImage: "link.badge.plus")
                }

                Button {
                    copyToClipboard(item.errorMessage ?? "Unknown error")
                } label: {
                    Label("Copy Error", systemImage: "doc.on.clipboard")
                }

            case .completed:
                Button {
                    openFile()
                } label: {
                    Label("Open File", systemImage: "folder")
                }

                ShareLink(
                    item: fileURL ?? URL(fileURLWithPath: item.fileName),
                    message: Text(item.fileName)
                ) {
                    Label("Share File", systemImage: "square.and.arrow.up")
                }

            case .pending:
                Button(role: .destructive) {
                    queueManager.cancelDownload(id: item.id)
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
            }

            Divider()

            // Always-present URL actions
            Button {
                copyToClipboard(item.url)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("Copy URL", systemImage: "link")
            }

            if item.status != .completed {
                ShareLink(item: URL(string: item.url) ?? URL(fileURLWithPath: "/")) {
                    Label("Share URL", systemImage: "square.and.arrow.up")
                }
            }

            Divider()

            // More info
            Button {
                onShowDetail()
            } label: {
                Label("More Info", systemImage: "info.circle")
            }
        }
    }

    // MARK: - Helpers

    private var fileURL: URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(item.fileName)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func openFile() {
        guard let url = fileURL else { return }
        // Present share sheet with the file so user can Open In…
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
