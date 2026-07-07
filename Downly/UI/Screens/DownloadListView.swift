import SwiftUI
import SwiftData

// MARK: - DownloadListView

/// Main download list, filtered by the selected ``DownloadFilter`` tab.
///
/// Uses `@Query` for automatic reactive updates when SwiftData records change.
struct DownloadListView: View {

    // MARK: - Dependencies

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var queueManager: DownloadQueueManager

    // MARK: - State

    @State private var selectedFilter: DownloadFilter = .all
    @State private var showAddSheet   = false
    @State private var isEditMode     = false
    @State private var selectedIDs:   Set<UUID> = []
    @State private var pendingDeleteID: UUID?   = nil
    @State private var showDeleteConfirm = false
    @State private var deleteFileAlso    = false
    @State private var cardFrames: [UUID: CGRect] = [:]

    // MARK: - Query

    @Query(sort: \DownloadItem.createdAt, order: .reverse)
    private var allItems: [DownloadItem]

    private var filteredItems: [DownloadItem] {
        let statuses = selectedFilter.matchingStatuses.map(\.rawValue)
        if selectedFilter == .all { return allItems }
        return allItems.filter { statuses.contains($0.statusRaw) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(DownloadFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)

                    LazyVStack(spacing: DS.Spacing.sm) {
                        if filteredItems.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredItems) { item in
                                HStack(spacing: DS.Spacing.sm) {
                                    // Leading checkbox (edit mode only)
                                    if isEditMode {
                                        selectionCheckbox(for: item)
                                            .transition(.move(edge: .leading).combined(with: .opacity))
                                    }

                                    DownloadItemCard(
                                        item: item,
                                        onPause:  { Task { await queueManager.pauseDownload(id: item.id) } },
                                        onResume: { queueManager.resumeDownload(id: item.id) },
                                        onCancel: { queueManager.cancelDownload(id: item.id) },
                                        onRetry:  { queueManager.resumeDownload(id: item.id) },
                                        isSelected: selectedIDs.contains(item.id),
                                        // In edit mode tap toggles selection; outside edit mode
                                        // the card opens the detail sheet on its own.
                                        onTap: isEditMode ? {
                                            withSpringAnimation {
                                                if selectedIDs.contains(item.id) {
                                                    selectedIDs.remove(item.id)
                                                } else {
                                                    selectedIDs.insert(item.id)
                                                }
                                            }
                                        } : nil
                                    )
                                    .reportCardFrame(id: item.id)
                                }
                                .id(item.id)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        pendingDeleteID = item.id
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                    .tint(DS.Colors.error)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.md)
                    // Extra bottom padding when edit mode is active to prevent
                    // the SelectionToolbar from overlapping the last card.
                    .padding(.bottom, isEditMode ? 80 : 0)
                }
                .scrollIndicators(.hidden)
                .coordinateSpace(name: "downloadList")
                .onPreferenceChange(CardFramePreferenceKey.self) { frames in
                    cardFrames = frames
                }
                // Two-finger gesture overlay — sits on top of scroll view.
                // allowsHitTesting(false) lets SwiftUI still receive single-finger
                // taps and scroll events; the UIView's UIPanGestureRecognizer fires
                // independently of SwiftUI's hit-test chain.
                .overlay {
                    TwoFingerPanOverlay(
                        isSelectionMode: $isEditMode,
                        selectedIDs: $selectedIDs,
                        cardFrames: cardFrames
                    )
                    .allowsHitTesting(false)
                }


            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditMode {
                        // Close (✕) button in edit mode
                        Button {
                            withSpringAnimation {
                                isEditMode = false
                                selectedIDs.removeAll()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(DS.Colors.labelSec)
                        }
                    } else {
                        Button {
                            withSpringAnimation { isEditMode = true }
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.Colors.label)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.Colors.label)
                }
                ToolbarItem(placement: .principal) {
                    Text("Downly")
                        .font(DS.Typography.title)
                        .foregroundStyle(DS.Colors.label)
                }
            }
            .animation(.downlySpring, value: isEditMode)
            // Selection toolbar anchored at bottom in edit mode
            .safeAreaInset(edge: .bottom) {
                if isEditMode {
                    SelectionToolbar(
                        selectedIDs: $selectedIDs,
                        isSelectionMode: $isEditMode,
                        allIDs: filteredItems.map(\.id),
                        onDeleteAll: {
                            let ids = selectedIDs
                            withSpringAnimation {
                                for id in ids { deleteItem(id: id, skipAutoClose: true) }
                                selectedIDs.removeAll()
                                isEditMode = false
                            }
                        },
                        onPauseAll: {
                            let ids = selectedIDs
                            Task {
                                for id in ids { await queueManager.pauseDownload(id: id) }
                            }
                        },
                        onResumeAll: {
                            for id in selectedIDs { queueManager.resumeDownload(id: id) }
                        }
                    )
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddDownloadSheet { url, fileName in
                try? queueManager.addDownload(url: url, fileName: fileName)
            }
        }
        .alert("Delete Download?", isPresented: $showDeleteConfirm, presenting: pendingDeleteID) { id in
            if let item = allItems.first(where: { $0.id == id }), item.status == .completed {
                Button("Remove Entry Only", role: .destructive) {
                    deleteItem(id: id, deleteFile: false)
                }
                Button("Delete Entry & File", role: .destructive) {
                    deleteItem(id: id, deleteFile: true)
                }
            } else {
                Button("Delete", role: .destructive) {
                    deleteItem(id: id, deleteFile: false)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { id in
            if let item = allItems.first(where: { $0.id == id }) {
                if item.status == .completed {
                    Text("\"\(item.fileName)\" — choose how to remove it.")
                } else {
                    Text("\"\(item.fileName)\" will be cancelled and removed.")
                }
            }
        }
    }

    // MARK: - Floating Delete FAB

    private var deleteFloatingButton: some View {
        Button {
            withSpringAnimation {
                for id in selectedIDs {
                    queueManager.cancelDownload(id: id)
                }
                selectedIDs.removeAll()
                // Keep edit mode active after deletion
            }
        } label: {
            Image(systemName: "trash.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(DS.Colors.error)
                .clipShape(Circle())
                .shadow(
                    color: DS.Shadow.fab.color,
                    radius: DS.Shadow.fab.radius,
                    x: DS.Shadow.fab.x,
                    y: DS.Shadow.fab.y
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Swipe-to-Delete

    /// Deletes a download.
    /// - Parameters:
    ///   - deleteFile: When `true` and the item is completed, also removes the file from disk.
    ///   - skipAutoClose: Pass `true` during batch deletions to suppress per-item auto-close;
    ///     the caller is responsible for closing edit mode after the loop.
    private func deleteItem(id: UUID, deleteFile: Bool = false, skipAutoClose: Bool = false) {
        guard let item = allItems.first(where: { $0.id == id }) else { return }
        if item.status == .completed {
            if deleteFile {
                // Remove both the record and the file on disk
                let fm = FileManager.default
                let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = docs.appendingPathComponent(item.fileName)
                try? fm.removeItem(at: fileURL)
            }
            modelContext.delete(item)
            try? modelContext.save()
            SpeedHistoryStore.shared.remove(for: id)
        } else {
            queueManager.cancelDownload(id: id)
            SpeedHistoryStore.shared.remove(for: id)
        }
        selectedIDs.remove(id)
        // Auto-exit edit mode when the last selected item has been removed
        if !skipAutoClose && selectedIDs.isEmpty {
            withSpringAnimation { isEditMode = false }
        }
    }


    private func selectionCheckbox(for item: DownloadItem) -> some View {
        Button {
            withSpringAnimation {
                if selectedIDs.contains(item.id) {
                    selectedIDs.remove(item.id)
                } else {
                    selectedIDs.insert(item.id)
                }
            }
        } label: {
            Image(systemName: selectedIDs.contains(item.id)
                    ? "checkmark.circle.fill"
                    : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selectedIDs.contains(item.id)
                    ? DS.Colors.accent
                    : DS.Colors.labelSec)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "arrow.down.circle.dotted")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(DS.Colors.labelSec)
            Text("No downloads yet")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Colors.label)
            Text("Tap + to add a file URL and start downloading.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.labelSec)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DS.Spacing.xxl)
        .padding(.horizontal, DS.Spacing.xl)
    }
}
