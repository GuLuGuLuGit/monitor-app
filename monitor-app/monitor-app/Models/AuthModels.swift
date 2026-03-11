import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let token: String
    let expiresAt: Date
    let admin: AdminInfo

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
        case admin
    }
}

struct RefreshTokenResponse: Codable {
    let token: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
    }
}

struct AdminInfo: Codable {
    let id: UInt
    let username: String
    let email: String
    let nickname: String
    let role: String
    let lastLoginAt: Date?
    let lastLoginIp: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email, nickname, role
        case lastLoginAt = "last_login_at"
        case lastLoginIp = "last_login_ip"
    }
}
