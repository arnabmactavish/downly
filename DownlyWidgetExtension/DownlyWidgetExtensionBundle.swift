import WidgetKit
import SwiftUI

/// Single entry point for the Downly widget extension.
///
/// Registers the Downly Live Activity widget.
/// Template stubs (DownlyWidgetExtension, DownlyWidgetExtensionControl,
/// DownlyWidgetExtensionLiveActivity) should be deleted from the project
/// once this bundle is the sole @main.
@main
struct DownlyWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        DownloadLiveActivityWidget()
    }
}

