import ApplicationServices
import Foundation

struct AccessibilityPermissionService: PermissionServiceProtocol {
    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
