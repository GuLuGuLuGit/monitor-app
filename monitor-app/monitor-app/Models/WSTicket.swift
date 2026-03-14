import Foundation

struct WSTicketRequest: Encodable {
    let scope: String
    let deviceId: String?
    let commandId: Int64?

    enum CodingKeys: String, CodingKey {
        case scope
        case deviceId = "device_id"
        case commandId = "command_id"
    }
}

struct WSTicketResponse: Decodable {
    let ticket: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case ticket
        case expiresAt = "expires_at"
    }
}
