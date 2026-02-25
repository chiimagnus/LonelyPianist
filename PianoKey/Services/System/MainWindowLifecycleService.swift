import AppKit

@MainActor
final class MainWindowLifecycleService: NSObject, NSWindowDelegate {
    func windowDidBecomeMain(_ notification: Notification) {
        DockPresenceService.prepareForPresentingMainWindow()
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            DockPresenceService.hideDockIfAllowedWhenNoVisibleWindows()
        }
    }
}
