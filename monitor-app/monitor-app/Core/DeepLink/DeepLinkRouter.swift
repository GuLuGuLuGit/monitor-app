import Foundation
import Observation

enum DeepLink: Equatable {
    case device(id: String)
    case command(id: Int64)
    case pairing

    static func from(notification userInfo: [AnyHashable: Any]) -> DeepLink? {
        guard let data = userInfo["data"] as? [String: Any] else { return nil }
        let type = data["type"] as? String

        switch type {
        case "device_online", "device_offline":
            if let deviceId = data["device_id"] as? String {
                return .device(id: deviceId)
            }
        case "command_completed", "command_failed":
            if let commandId = data["command_id"] as? Int64 {
                return .command(id: commandId)
            }
        default:
            break
        }
        return nil
    }
}

@Observable
@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    var pendingDeepLink: DeepLink?
    var selectedTab: Int = 0

    private init() {}

    func handle(_ deepLink: DeepLink) {
        switch deepLink {
        case .device:
            selectedTab = 0
            pendingDeepLink = deepLink
        case .command:
            selectedTab = 1
            pendingDeepLink = deepLink
        case .pairing:
            selectedTab = 0
            pendingDeepLink = deepLink
        }
    }

    func consumeDeepLink() -> DeepLink? {
        let link = pendingDeepLink
        pendingDeepLink = nil
        return link
    }
}
