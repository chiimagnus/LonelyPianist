import AppKit
import CoreGraphics
import Foundation

struct AccessibilityPermissionService: PermissionServiceProtocol {
    func hasAccessibilityPermission() -> Bool {
        CGPreflightPostEventAccess()
    }

    func requestAccessibilityPermission() -> Bool {
        CGRequestPostEventAccess()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
