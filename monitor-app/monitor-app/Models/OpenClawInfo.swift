import Foundation

struct OpenClawInfo: Codable {
    let overview: OpenClawOverview?
    let agents: [OpenClawAgent]?
    let channels: [OpenClawChannel]?
    let bindings: [OpenClawBinding]?
    let model: String?
    let diagnosis: OpenClawDiagnosis?
}

extension OpenClawInfo {
    /// Manual fallback parser for when Codable fails
    static func fromRawJSON(_ json: [String: Any]) -> OpenClawInfo? {
        var agents: [OpenClawAgent] = []
        if let agentArr = json["agents"] as? [[String: Any]] {
            for (idx, a) in agentArr.enumerated() {
                let id = (a["id"] as? String) ?? "agent-\(idx)"
                let name = (a["name"] as? String) ?? id
                var sessions: Int?
                if let s = a["sessions"] as? Int { sessions = s }
                else if let s = a["sessions"] as? String, let n = Int(s) { sessions = n }
                let active = a["active"] as? String
                let bootstrap = a["bootstrap"] as? String
                agents.append(OpenClawAgent(id: id, name: name, sessions: sessions, active: active, bootstrap: bootstrap))
            }
        }

        var channels: [OpenClawChannel] = []
        if let chArr = json["channels"] as? [[String: Any]] {
            for ch in chArr {
                let type = (ch["type"] as? String) ?? "unknown"
                let enabled = (ch["enabled"] as? Bool) ?? false
                let state = ch["state"] as? String
                let detail = ch["detail"] as? String
                channels.append(OpenClawChannel(type: type, enabled: enabled, state: state, detail: detail, accounts: nil))
            }
        }

        var overview: OpenClawOverview?
        if let ov = json["overview"] as? [String: Any] {
            overview = OpenClawOverview(
                version: ov["version"] as? String,
                os: ov["os"] as? String,
                node: ov["node"] as? String,
                config: ov["config"] as? String,
                dashboard: ov["dashboard"] as? String,
                tailscale: ov["tailscale"] as? String,
                channel: ov["channel"] as? String,
                update: ov["update"] as? String,
                gateway: ov["gateway"] as? String,
                gatewaySelf: ov["gateway_self"] as? String,
                gatewayService: ov["gateway_service"] as? String,
                nodeService: ov["node_service"] as? String,
                agentsSummary: ov["agents_summary"] as? String
            )
        }

        let hasData = overview != nil || !agents.isEmpty || !channels.isEmpty || json["model"] != nil
        guard hasData else { return nil }

        return OpenClawInfo(
            overview: overview,
            agents: agents.isEmpty ? nil : agents,
            channels: channels.isEmpty ? nil : channels,
            bindings: nil,
            model: json["model"] as? String,
            diagnosis: nil
        )
    }

    static func parseAgentsResult(_ text: String) -> [OpenClawAgent] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let agents = decodeAgentsJSON(trimmed) {
            return agents
        }

        // Some agents may return a JSON string or wrap the array in extra text.
        if let data = trimmed.data(using: .utf8),
           let wrapped = try? JSONDecoder().decode(String.self, from: data),
           let agents = decodeAgentsJSON(wrapped.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return agents
        }

        if let start = trimmed.firstIndex(of: "["),
           let end = trimmed.lastIndex(of: "]"),
           start <= end {
            let jsonArray = String(trimmed[start...end])
            if let agents = decodeAgentsJSON(jsonArray) {
                return agents
            }
        }

        return []
    }

    private static func decodeAgentsJSON(_ text: String) -> [OpenClawAgent]? {
        guard let data = text.data(using: .utf8) else { return nil }
        if let decoded = try? JSONDecoder().decode([OpenClawAgent].self, from: data) {
            return decoded
        }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let rawAgents = object["agents"] as? [[String: Any]] {
                return mapAgents(rawAgents)
            }
            if let rawAgents = object["data"] as? [[String: Any]] {
                return mapAgents(rawAgents)
            }
        }
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return mapAgents(raw)
        }
        return nil
    }

    private static func mapAgents(_ raw: [[String: Any]]) -> [OpenClawAgent] {
        raw.enumerated().compactMap { idx, item in
            let id = (item["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !id.isEmpty else { return nil }
            let name = (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            var sessions: Int?
            if let s = item["sessions"] as? Int { sessions = s }
            else if let s = item["sessions"] as? String, let n = Int(s) { sessions = n }
            let active = item["active"] as? String
            let bootstrap = item["bootstrap"] as? String
            return OpenClawAgent(
                id: id,
                name: (name?.isEmpty == false ? name! : "agent-\(idx)"),
                sessions: sessions,
                active: active,
                bootstrap: bootstrap
            )
        }
    }
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

    init(id: String, name: String, sessions: Int? = nil, active: String? = nil, bootstrap: String? = nil) {
        self.id = id
        self.name = name
        self.sessions = sessions
        self.active = active
        self.bootstrap = bootstrap
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? container.decode(String.self, forKey: .name)) ?? id
        // sessions can be int or string in some OpenClaw versions
        if let intVal = try? container.decode(Int.self, forKey: .sessions) {
            sessions = intVal
        } else if let strVal = try? container.decode(String.self, forKey: .sessions), let n = Int(strVal) {
            sessions = n
        } else {
            sessions = nil
        }
        active = try? container.decode(String.self, forKey: .active)
        bootstrap = try? container.decode(String.self, forKey: .bootstrap)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, sessions, active, bootstrap
    }
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
