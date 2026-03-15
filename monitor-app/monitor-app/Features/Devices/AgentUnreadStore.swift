import Foundation

enum AgentUnreadStore {
    static let didChangeNotification = Notification.Name("agentUnreadStoreDidChange")

    private static let seenKey = "agent_message_unread_seen_at_v2"

    static func seenDate(deviceId: String, agentId: String) -> Date {
        let formatter = ISO8601DateFormatter()
        guard let raw = seenMap()[storageKey(deviceId: deviceId, agentId: agentId)],
              let date = formatter.date(from: raw) else {
            return .distantPast
        }
        return date
    }

    static func markRead(deviceId: String, agentId: String, at date: Date = Date()) {
        var map = seenMap()
        map[storageKey(deviceId: deviceId, agentId: agentId)] = ISO8601DateFormatter().string(from: date)
        UserDefaults.standard.set(map, forKey: seenKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static func storageKey(deviceId: String, agentId: String) -> String {
        "\(deviceId)::\(agentId)"
    }

    private static func seenMap() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: seenKey) as? [String: String] ?? [:]
    }
}
