import AppKit

enum DockPresenceService {
    @MainActor
    static func showDockIcon() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func hideDockIcon() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
