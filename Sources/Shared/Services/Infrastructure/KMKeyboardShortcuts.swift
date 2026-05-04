import Foundation

// MARK: - Notification Names for Keyboard Shortcuts
extension Notification.Name {
    static let createNewPage = Notification.Name("KMCreateNewPage")
    static let performSave = Notification.Name("KMPerformSave")
    static let focusSearch = Notification.Name("KMFocusSearch")
    static let performUndo = Notification.Name("KMPerformUndo")
    static let performRedo = Notification.Name("KMPerformRedo")
    static let closeWindow = Notification.Name("KMCloseWindow")
    static let openSettings = Notification.Name("KMOpenSettings")
    static let quitApp = Notification.Name("KMQuitApp")
}