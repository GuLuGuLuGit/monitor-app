import Foundation

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE
}

enum APIEndpoint {
    // Auth
    case login
    case register
    case sendCode
    case resetPassword
    case refreshToken
    case me
    case wsTicket

    // Dashboard
    case dashboard

    // Devices
    case devices
    case device(id: UInt)
    case devicePublicKey(id: UInt)
    case deviceAgentRead(id: UInt)
    case deviceStatus(id: UInt)
    case deleteDevice(id: UInt)

    // Metrics
    case metrics

    // Commands
    case commands
    case command(id: Int64)
    case createCommand

    // Tasks
    case taskStats
    case taskProgress(id: Int64)
    case taskProgressLatest(id: Int64)

    // Skills
    case skills

    // Pairing
    case pairingConfirm

    // Push (M4)
    case registerPushToken

    var path: String {
        switch self {
        case .login:                    "/admin/auth/login"
        case .register:                 "/admin/auth/register"
        case .sendCode:                 "/admin/auth/send-code"
        case .resetPassword:            "/admin/auth/reset-password"
        case .refreshToken:             "/admin/auth/refresh"
        case .me:                       "/admin/auth/me"
        case .wsTicket:                 "/admin/ws-ticket"
        case .dashboard:                "/admin/dashboard"
        case .devices:                  "/admin/devices"
        case .device(let id):           "/admin/devices/\(id)"
        case .devicePublicKey(let id):  "/admin/devices/\(id)/public-key"
        case .deviceAgentRead(let id):  "/admin/devices/\(id)/agents/read"
        case .deviceStatus(let id):     "/admin/devices/\(id)/status"
        case .deleteDevice(let id):     "/admin/devices/\(id)"
        case .metrics:                  "/admin/metrics"
        case .commands:                 "/admin/commands"
        case .command(let id):          "/admin/commands/\(id)"
        case .createCommand:            "/admin/commands"
        case .taskStats:                "/admin/tasks/stats"
        case .taskProgress(let id):     "/admin/tasks/\(id)/progress"
        case .taskProgressLatest(let id): "/admin/tasks/\(id)/progress/latest"
        case .skills:                   "/admin/skills"
        case .pairingConfirm:           "/admin/pairing/confirm"
        case .registerPushToken:        "/admin/devices/push-token"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .register, .sendCode, .resetPassword, .refreshToken, .wsTicket, .createCommand, .pairingConfirm, .registerPushToken, .deviceAgentRead:
            .POST
        case .deviceStatus:
            .PUT
        case .deleteDevice:
            .DELETE
        default:
            .GET
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .register, .sendCode, .resetPassword:
            false
        default:
            true
        }
    }

    func urlRequest(baseURL: URL) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        return request
    }

    func urlRequest(baseURL: URL, queryItems: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        return request
    }
}
