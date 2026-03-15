import Foundation

enum AgentUnreadStore {
    static let didChangeNotification = Notification.Name("agentUnreadStoreDidChange")

    static func notifyDidChange() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
