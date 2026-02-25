import AppKit

enum DockPresenceService {
    @MainActor
    static func prepareForPresentingMainWindow() {
        let app = NSApplication.shared
        if app.activationPolicy() != .regular {
            app.setActivationPolicy(.regular)
        }
        app.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func hideDockIfAllowedWhenNoVisibleWindows() {
        let app = NSApplication.shared

        let hasVisibleMainWindows = app.windows.contains(where: { $0.isVisible && $0.canBecomeMain })
        guard !hasVisibleMainWindows else { return }

        if app.activationPolicy() != .accessory {
            app.setActivationPolicy(.accessory)
        }
    }
}
