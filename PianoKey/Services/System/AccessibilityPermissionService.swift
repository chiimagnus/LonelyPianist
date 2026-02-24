import AppKit
import ApplicationServices
import Foundation

struct AccessibilityPermissionService: PermissionServiceProtocol {
    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: kCFBooleanTrue as Any
        ] as CFDictionary

        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        return trusted
    }
}
