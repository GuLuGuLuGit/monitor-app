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
    static func parse(from raw: String?) -> OpenClawInfo? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(OpenClawInfo.self, from: data) {
            return decoded
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return OpenClawInfo.fromRawJSON(json)
        }
        return nil
    }
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
                let agentOnline = a["agent_online"] as? Bool
                let sessionModel = a["session_model"] as? String
                let sessionTokens = a["session_tokens"] as? String
                agents.append(OpenClawAgent(id: id, name: name, sessions: sessions, active: active, bootstrap: bootstrap, sessionModel: sessionModel, sessionTokens: sessionTokens, agentOnline: agentOnline))
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
            let sessionModel = item["session_model"] as? String
            let sessionTokens = item["session_tokens"] as? String
            let agentOnline = item["agent_online"] as? Bool
            return OpenClawAgent(
                id: id,
                name: (name?.isEmpty == false ? name! : "agent-\(idx)"),
                sessions: sessions,
                active: active,
                bootstrap: bootstrap,
                sessionModel: sessionModel,
                sessionTokens: sessionTokens,
                agentOnline: agentOnline
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
    let sessionModel: String?
    let sessionTokens: String?
    let agentOnline: Bool?

    init(id: String, name: String, sessions: Int? = nil, active: String? = nil, bootstrap: String? = nil, sessionModel: String? = nil, sessionTokens: String? = nil, agentOnline: Bool? = nil) {
        self.id = id
        self.name = name
        self.sessions = sessions
        self.active = active
        self.bootstrap = bootstrap
        self.sessionModel = sessionModel
        self.sessionTokens = sessionTokens
        self.agentOnline = agentOnline
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
        sessionModel = try? container.decode(String.self, forKey: .sessionModel)
        sessionTokens = try? container.decode(String.self, forKey: .sessionTokens)
        agentOnline = try? container.decode(Bool.self, forKey: .agentOnline)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, sessions, active, bootstrap
        case sessionModel = "session_model"
        case sessionTokens = "session_tokens"
        case agentOnline = "agent_online"
    }
}

extension OpenClawAgent {
    func isLikelyOnline(recentActivityAt: Date? = nil, optimistic: Bool = false, now: Date = Date()) -> Bool {
        if optimistic {
            return true
        }
        if let agentOnline {
            return agentOnline
        }

        if let active = active?.trimmingCharacters(in: .whitespacesAndNewlines),
           !active.isEmpty {
            let lower = active.lowercased()
            if ["true", "yes", "online", "active", "now"].contains(lower) {
                return true
            }
            if let age = Self.parseActiveAge(lower), age == 0 {
                return true
            }
        }

        if let recentActivityAt, now.timeIntervalSince(recentActivityAt) <= 900 {
            return true
        }

        return false
    }

    private static func parseActiveAge(_ value: String) -> TimeInterval? {
        let parts = value.split(separator: " ")
        guard let token = parts.first else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let unit = trimmed.last else { return nil }
        let numberStr = trimmed.dropLast()
        guard let num = Double(numberStr) else { return nil }

        switch unit {
        case "s": return num
        case "m": return num * 60
        case "h": return num * 3600
        case "d": return num * 86400
        case "w": return num * 604800
        default: return nil
        }
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
