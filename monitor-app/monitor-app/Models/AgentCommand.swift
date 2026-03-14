import Foundation

struct AgentCommand: Codable, Identifiable {
    let id: Int64
    let deviceId: String
    let commandType: String
    let commandParams: [String: AnyCodable]?
    let encryptedPayload: String?
    let isEncrypted: Bool
    let status: Int8
    let result: String
    let errorMessage: String
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date
    let executedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case commandType = "command_type"
        case commandParams = "command_params"
        case encryptedPayload = "encrypted_payload"
        case isEncrypted = "is_encrypted"
        case status, result
        case errorMessage = "error_message"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case executedAt = "executed_at"
    }
}

extension AgentCommand {
    enum Status: Int8, CaseIterable {
        case pending = 0
        case running = 1
        case success = 2
        case failed = 3
        case timeout = 4

        var label: String {
            switch self {
            case .pending: "待执行"
            case .running: "执行中"
            case .success: "成功"
            case .failed: "失败"
            case .timeout: "超时"
            }
        }
    }

    enum CommandGroup: String, CaseIterable {
        case control
        case diagnose
        case manage

        var label: String {
            switch self {
            case .control: "服务控制"
            case .diagnose: "诊断与查询"
            case .manage: "运维管理"
            }
        }

        var types: [CommandType] {
            switch self {
            case .control: [.start, .stop, .restart, .gateway]
            case .diagnose: [.status, .doctor, .probe, .logs]
            case .manage: [.config, .update, .sessions, .security]
            }
        }
    }

    enum CommandType: String, CaseIterable {
        case start = "openclaw_start"
        case stop = "openclaw_stop"
        case restart = "openclaw_restart"
        case status = "openclaw_status"
        case agents = "openclaw_agents"
        case config = "openclaw_config"
        case doctor = "openclaw_doctor"
        case update = "openclaw_update"
        case logs = "openclaw_logs"
        case probe = "openclaw_probe"
        case sessions = "openclaw_sessions"
        case security = "openclaw_security"
        case gateway = "openclaw_gateway"
        case message = "openclaw_message"

        var label: String {
            switch self {
            case .start: "启动"
            case .stop: "停止"
            case .restart: "重启"
            case .status: "状态"
            case .agents: "Agents"
            case .config: "配置"
            case .doctor: "诊断"
            case .update: "更新"
            case .logs: "日志"
            case .probe: "连通性"
            case .sessions: "会话"
            case .security: "安全"
            case .gateway: "Gateway"
            case .message: "消息"
            }
        }

        var icon: String {
            switch self {
            case .start: "play.circle.fill"
            case .stop: "stop.circle.fill"
            case .restart: "arrow.clockwise.circle.fill"
            case .status: "info.circle.fill"
            case .agents: "person.3.fill"
            case .config: "gearshape.fill"
            case .doctor: "stethoscope"
            case .update: "arrow.up.circle.fill"
            case .logs: "doc.text.fill"
            case .probe: "antenna.radiowaves.left.and.right"
            case .sessions: "bubble.left.and.bubble.right.fill"
            case .security: "shield.checkered"
            case .gateway: "globe"
            case .message: "message.fill"
            }
        }

        var needsParams: Bool {
            switch self {
            case .gateway, .logs, .update, .sessions, .security, .config, .message:
                return true
            default:
                return false
            }
        }
    }

    var commandStatus: Status {
        Status(rawValue: status) ?? .pending
    }

    var commandTypeEnum: CommandType? {
        CommandType(rawValue: commandType)
    }
}

/// Type-erased Codable wrapper for JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
