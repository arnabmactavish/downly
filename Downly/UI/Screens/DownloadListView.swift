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
                                        onRetry:  { queueManager.resumeDownload(id: item.id) }
                                    )
                                }
                                .id(item.id)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.md)
                    // Extra bottom padding when edit mode is active to prevent
                    // the FAB from overlapping the last card.
                    .padding(.bottom, isEditMode ? 80 : 0)
                }
                .scrollIndicators(.hidden)

                // Floating delete FAB
                if isEditMode && !selectedIDs.isEmpty {
                    deleteFloatingButton
                        .transition(.scale.combined(with: .opacity))
                        .padding(DS.Spacing.lg)
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
        }
        .sheet(isPresented: $showAddSheet) {
            AddDownloadSheet { url, fileName in
                try? queueManager.addDownload(url: url, fileName: fileName)
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

    // MARK: - Selection Checkbox (edit mode)

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
