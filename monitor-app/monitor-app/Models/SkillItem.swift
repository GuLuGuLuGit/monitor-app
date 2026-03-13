import Foundation

struct SkillItem: Codable, Identifiable {
    let id: Int
    let deviceId: Int
    let skillName: String
    let skillVersion: String?
    let enabled: Bool
    let lastUsedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case skillName = "skill_name"
        case skillVersion = "skill_version"
        case enabled
        case lastUsedAt = "last_used_at"
    }
}

struct SkillListResponse: Decodable {
    let items: [SkillItem]
    let pagination: SkillPagination?
}

struct SkillPagination: Decodable {
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case total, page
        case pageSize = "page_size"
    }
}
