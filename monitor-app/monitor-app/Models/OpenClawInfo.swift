import Foundation

struct OpenClawInfo: Codable {
    let overview: OpenClawOverview?
    let agents: [OpenClawAgent]?
    let channels: [OpenClawChannel]?
    let bindings: [OpenClawBinding]?
    let model: String?
    let diagnosis: OpenClawDiagnosis?
}

struct OpenClawOverview: Codable {
    let version: String?
    let os: String?
    let node: String?
    let config: String?
    let dashboard: String?
    let tailscale: String?
    let channel: String?
    let update: String?
    let gateway: String?
    let gatewaySelf: String?
    let gatewayService: String?
    let nodeService: String?
    let agentsSummary: String?

    enum CodingKeys: String, CodingKey {
        case version, os, node, config, dashboard, tailscale, channel, update, gateway
        case gatewaySelf = "gateway_self"
        case gatewayService = "gateway_service"
        case nodeService = "node_service"
        case agentsSummary = "agents_summary"
    }
}

struct OpenClawAgent: Codable, Identifiable {
    var id: String
    let name: String
    let sessions: Int?
    let active: String?
    let bootstrap: String?
}

struct OpenClawAccount: Codable, Identifiable {
    var id: String
    let enabled: Bool
    let status: String?
}

struct OpenClawChannel: Codable, Identifiable {
    var id: String { type }
    let type: String
    let enabled: Bool
    let state: String?
    let detail: String?
    let accounts: [OpenClawAccount]?
}

struct OpenClawBinding: Codable {
    let agentId: String
    let channel: String
    let accountId: String

    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case channel
        case accountId = "account_id"
    }
}

struct OpenClawDiagnosis: Codable {
    let skillsEligible: Int?
    let skillsMissing: Int?
    let channelIssues: String?

    enum CodingKeys: String, CodingKey {
        case skillsEligible = "skills_eligible"
        case skillsMissing = "skills_missing"
        case channelIssues = "channel_issues"
    }
}
