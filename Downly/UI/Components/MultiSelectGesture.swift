import SwiftUI
import UIKit

// MARK: - CardFramePreferenceKey

/// Preference key that collects the frame of each download card in the scroll view's
/// coordinate space, keyed by download ID. Used by TwoFingerPanOverlay for hit-testing.
struct CardFramePreferenceKey: PreferenceKey {
    typealias Value = [UUID: CGRect]
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - CardFrameReader

/// Attach to each DownloadItemCard to report its frame up via preferences.
struct CardFrameReader: ViewModifier {
    let id: UUID

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: CardFramePreferenceKey.self,
                            value: [id: geo.frame(in: .named("downloadList"))]
                        )
                }
            )
    }
}

extension View {
    func reportCardFrame(id: UUID) -> some View {
        modifier(CardFrameReader(id: id))
    }
}

// MARK: - TwoFingerPanOverlay

/// A UIViewRepresentable transparent overlay that detects two-finger pan gestures
/// and drives selection mode in the parent SwiftUI view.
///
/// Hit-testing maps the gesture's midpoint Y to overlapping card frames
/// recorded via CardFramePreferenceKey.
struct TwoFingerPanOverlay: UIViewRepresentable {

    /// Binding that triggers selection mode activation.
    @Binding var isSelectionMode: Bool

    /// Binding into the set of selected IDs — toggled as fingers sweep over cards.
    @Binding var selectedIDs: Set<UUID>

    /// Current card frames in the scroll coordinate space.
    let cardFrames: [UUID: CGRect]

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        var parent: TwoFingerPanOverlay

        init(_ parent: TwoFingerPanOverlay) {
            self.parent = parent
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: gesture.view)

            switch gesture.state {
            case .began:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.async {
                    withAnimation(.downlySpring) {
                        self.parent.isSelectionMode = true
                    }
                }
                toggleCard(at: location)

            case .changed:
                toggleCard(at: location)

            default:
                break
            }
        }

        private func toggleCard(at location: CGPoint) {
            for (id, frame) in parent.cardFrames where frame.contains(location) {
                DispatchQueue.main.async {
                    withAnimation(.downlySpring) {
                        if self.parent.selectedIDs.contains(id) {
                            self.parent.selectedIDs.remove(id)
                        } else {
                            self.parent.selectedIDs.insert(id)
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                }
                break
            }
        }

        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Always allow simultaneous recognition so the scroll view's internal
            // pan gesture (a private UIScrollView subclass) can still scroll the
            // list while our two-finger pan is in progress.
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            return false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = context.coordinator
        // Do NOT cancel touches in view — lets SwiftUI button taps underneath
        // still fire even while a two-finger pan is being recognised.
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }
}

// MARK: - SelectionToolbar

/// Floating toolbar shown when selection mode is active.
struct SelectionToolbar: View {

    @Binding var selectedIDs: Set<UUID>
    @Binding var isSelectionMode: Bool

    let allIDs: [UUID]
    let onDeleteAll: () -> Void
    let onPauseAll:  () -> Void
    let onResumeAll: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            // Top row: count + select-all + done
            HStack(spacing: DS.Spacing.sm) {
                // Count
                Text(selectedIDs.isEmpty
                     ? "None selected"
                     : "\(selectedIDs.count) selected")
                    .font(DS.Typography.captionBold)
                    .foregroundStyle(DS.Colors.label)
                    .contentTransition(.numericText())
                    .animation(.downlySpring, value: selectedIDs.count)

                Spacer()

                // Select All / Deselect All
                Button(selectedIDs.count == allIDs.count ? "Deselect All" : "Select All") {
                    withSpringAnimation {
                        if selectedIDs.count == allIDs.count {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = Set(allIDs)
                        }
                    }
                }
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.accent)

                // Done
                Button("Done") {
                    withSpringAnimation {
                        isSelectionMode = false
                        selectedIDs.removeAll()
                    }
                }
                .font(DS.Typography.captionBold)
                .foregroundStyle(DS.Colors.label)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .liquidGlass(cornerRadius: DS.Radius.md)

            // Batch action row — only visible when items are selected
            if !selectedIDs.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    batchButton(title: "Pause All",  icon: "pause.fill", tint: DS.Colors.accent,  action: onPauseAll)
                    batchButton(title: "Resume All", icon: "play.fill",  tint: DS.Colors.success, action: onResumeAll)
                    batchButton(title: "Delete All", icon: "trash.fill", tint: DS.Colors.error,   action: onDeleteAll)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.downlySpring, value: selectedIDs.isEmpty)
    }

    private func batchButton(
        title: String, icon: String, tint: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(DS.Typography.captionBold)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xs)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}
