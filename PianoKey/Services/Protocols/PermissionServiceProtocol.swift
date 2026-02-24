import Foundation

protocol PermissionServiceProtocol {
    func hasAccessibilityPermission() -> Bool
    func requestAccessibilityPermission() -> Bool
}
