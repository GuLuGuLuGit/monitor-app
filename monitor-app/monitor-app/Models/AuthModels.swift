import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RegisterRequest: Encodable {
    let username: String
    let email: String
    let password: String
    let code: String
}

struct SendCodeRequest: Encodable {
    let email: String
    let type: String
}

struct ResetPasswordRequest: Encodable {
    let email: String
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case email, code
        case newPassword = "new_password"
    }
}

struct MessageResponse: Decodable {
    let message: String
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
