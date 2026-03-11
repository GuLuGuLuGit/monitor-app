import Foundation

enum AppConfig {
    #if DEBUG
    static let defaultBaseURL = "http://localhost:8080/api/v1"
    static let defaultWSBaseURL = "ws://localhost:8080/api/v1"
    #else
    static let defaultBaseURL = "https://your-server.com/api/v1"
    static let defaultWSBaseURL = "wss://your-server.com/api/v1"
    #endif

    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: "server_base_url") ?? defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: "server_base_url") }
    }

    static var wsBaseURL: String {
        get { UserDefaults.standard.string(forKey: "server_ws_url") ?? defaultWSBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: "server_ws_url") }
    }

    static let keychainService = "com.openclaw.monitor.ios"
    static let tokenKeychainAccount = "jwt_token"
    static let refreshTokenKeychainAccount = "refresh_token"

    static let heartbeatInterval: TimeInterval = 10
    static let detailRefreshInterval: TimeInterval = 5
}
