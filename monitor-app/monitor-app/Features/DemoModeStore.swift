import Foundation

extension Notification.Name {
    static let demoModeDataDidChange = Notification.Name("demoModeDataDidChange")
}

@MainActor
final class DemoModeStore {
    static let shared = DemoModeStore()

    static let demoUsername = "demo"
    static let demoPassword = "demo123456"

    struct ConversationMessage {
        let id: String
        let role: ChatMessage.Role
        let content: String
        let time: Date
        let status: Int8
        let inputType: ChatMessage.InputType
    }

    private struct AgentState {
        let id: String
        var name: String
        var online: Bool
        var unreadCount: Int
        var sessionModel: String
        var sessionTokens: String
        var lastActivityAt: Date?
    }

    private struct DeviceState {
        let id: UInt
        let deviceId: String
        let nodeId: String
        var hostname: String
        let macAddress: String
        let osVersion: String
        let cpuModel: String
        let cpuCores: Int
        let memoryTotal: Int64
        let diskTotal: Int64
        let agentVersion: String
        var status: Int8
        var lastHeartbeatAt: Date?
        let registeredAt: Date
        var updatedAt: Date
        var overview: OpenClawOverview
        var agents: [AgentState]
        var metrics: [SystemMetric]
        var skills: [SkillItem]
    }

    private var devicesById: [UInt: DeviceState] = [:]
    private var deviceOrder: [UInt] = []
    private var commandsById: [Int64: AgentCommand] = [:]
    private var commandOrder: [Int64] = []
    private var nextCommandId: Int64 = 1_000

    private init() {
        reset()
    }

    func reset() {
        let now = Date()
        let demoDevice1 = buildPrimaryDevice(now: now)
        let demoDevice2 = buildOfflineDevice(now: now)

        devicesById = [
            demoDevice1.id: demoDevice1,
            demoDevice2.id: demoDevice2,
        ]
        deviceOrder = [demoDevice1.id, demoDevice2.id]
        commandsById = [:]
        commandOrder = []
        nextCommandId = 1_000

        seedCommandHistory(now: now)
        publishChanges()
    }

    func devices() -> [Device] {
        deviceOrder.compactMap { id in devicesById[id].map(makeDevice(from:)) }
    }

    func device(id: UInt) -> Device? {
        guard let state = devicesById[id] else { return nil }
        return makeDevice(from: state)
    }

    func metrics(deviceId: UInt) -> [SystemMetric] {
        devicesById[deviceId]?.metrics.sorted { $0.metricTime < $1.metricTime } ?? []
    }

    func skills(deviceId: UInt) -> [SkillItem] {
        devicesById[deviceId]?.skills ?? []
    }

    func recentAgentActivity(deviceId: String) -> [String: Date] {
        guard let state = devicesById.values.first(where: { $0.deviceId == deviceId }) else { return [:] }
        var latest: [String: Date] = [:]
        for agent in state.agents {
            if let at = agent.lastActivityAt {
                latest[agent.id] = at
            }
        }
        return latest
    }

    func updateDeviceStatus(id: UInt, status: Int8) -> Device? {
        guard var state = devicesById[id] else { return nil }
        state.status = status
        state.updatedAt = Date()
        if status == Device.Status.online.rawValue {
            state.lastHeartbeatAt = Date()
        }
        devicesById[id] = state
        publishChanges()
        return makeDevice(from: state)
    }

    func deleteDevice(id: UInt) {
        guard let state = devicesById.removeValue(forKey: id) else { return }
        deviceOrder.removeAll { $0 == id }

        let relatedCommandIds = commandsById.values
            .filter { $0.deviceId == state.deviceId }
            .map(\ .id)
        for commandId in relatedCommandIds {
            commandsById.removeValue(forKey: commandId)
            commandOrder.removeAll { $0 == commandId }
        }
        publishChanges()
    }

    func commands(deviceId: String? = nil) -> [AgentCommand] {
        let ordered = commandOrder.compactMap { commandsById[$0] }
        let filtered = ordered.filter { deviceId == nil || $0.deviceId == deviceId }
        return filtered.sorted { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
    }

    func command(id: Int64) -> AgentCommand? {
        commandsById[id]
    }

    @discardableResult
    func sendCommand(deviceInternalId: UInt, commandType: AgentCommand.CommandType, params: [String: Any]? = nil) -> AgentCommand? {
        guard let device = devicesById[deviceInternalId] else { return nil }

        let now = Date()
        let commandId = nextCommandId
        nextCommandId += 1

        let persistedParams = params?.mapValues { AnyCodable($0) }
        let initialCommand = AgentCommand(
            id: commandId,
            deviceId: device.deviceId,
            commandType: commandType.rawValue,
            commandParams: persistedParams,
            encryptedPayload: nil,
            isEncrypted: false,
            status: AgentCommand.Status.running.rawValue,
            result: "",
            errorMessage: "",
            createdBy: "demo",
            createdAt: now,
            updatedAt: now,
            executedAt: nil
        )
        commandsById[commandId] = initialCommand
        commandOrder.insert(commandId, at: 0)
        publishChanges()

        scheduleCommandCompletion(deviceInternalId: deviceInternalId, commandId: commandId, commandType: commandType, params: params)
        return initialCommand
    }

    func deleteCommand(id: Int64) -> Bool {
        guard commandsById.removeValue(forKey: id) != nil else { return false }
        commandOrder.removeAll { $0 == id }
        publishChanges()
        return true
    }

    func cleanupCommands(deviceId: String? = nil, commandTypes: [String]? = nil, statuses: [Int8]? = nil) -> Int64 {
        let idsToDelete = commandsById.values.filter { command in
            if let deviceId, command.deviceId != deviceId { return false }
            if let commandTypes, !commandTypes.contains(command.commandType) { return false }
            if let statuses, !statuses.contains(command.status) { return false }
            return [AgentCommand.Status.success.rawValue, AgentCommand.Status.failed.rawValue, AgentCommand.Status.timeout.rawValue].contains(command.status)
        }.map(\ .id)

        for id in idsToDelete {
            commandsById.removeValue(forKey: id)
            commandOrder.removeAll { $0 == id }
        }
        if !idsToDelete.isEmpty {
            publishChanges()
        }
        return Int64(idsToDelete.count)
    }

    func chatHistory(deviceId: String, agentId: String, limit: Int) -> [ConversationMessage] {
        let history = commands(deviceId: deviceId)
            .filter { $0.commandType == AgentCommand.CommandType.message.rawValue }
            .filter { ($0.commandParams?["agent_id"]?.value as? String) == agentId }
            .sorted { $0.createdAt < $1.createdAt }

        var messages: [ConversationMessage] = []
        for cmd in history.suffix(limit) {
            let inputTypeRaw = cmd.commandParams?["input_type"]?.value as? String
            let messageText = cmd.commandParams?["message"]?.value as? String ?? ""
            let inputType: ChatMessage.InputType = inputTypeRaw == "voice" ? .voice : .text
            messages.append(ConversationMessage(
                id: "user-\(cmd.id)",
                role: .user,
                content: messageText,
                time: cmd.createdAt,
                status: cmd.status,
                inputType: inputType
            ))
            if !cmd.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append(ConversationMessage(
                    id: "reply-\(cmd.id)",
                    role: .assistant,
                    content: cmd.result,
                    time: cmd.executedAt ?? cmd.updatedAt,
                    status: AgentCommand.Status.success.rawValue,
                    inputType: .text
                ))
            }
        }
        return messages
    }

    func markAgentRead(deviceId: String, agentId: String) {
        guard let stateId = devicesById.values.first(where: { $0.deviceId == deviceId })?.id,
              var state = devicesById[stateId],
              let index = state.agents.firstIndex(where: { $0.id == agentId }) else {
            return
        }
        guard state.agents[index].unreadCount != 0 else { return }
        state.agents[index].unreadCount = 0
        devicesById[stateId] = state
        publishChanges()
    }

    private func publishChanges() {
        WidgetSnapshotStore.save(devices: devices())
        NotificationCenter.default.post(name: .deviceDataShouldRefresh, object: nil)
        NotificationCenter.default.post(name: .demoModeDataDidChange, object: nil)
    }

    private func scheduleCommandCompletion(deviceInternalId: UInt, commandId: Int64, commandType: AgentCommand.CommandType, params: [String: Any]?) {
        let completionDelay: Duration = commandType == .message ? .seconds(2) : .seconds(1)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: completionDelay)
            self?.completeCommand(deviceInternalId: deviceInternalId, commandId: commandId, commandType: commandType, params: params)
        }
    }

    private func completeCommand(deviceInternalId: UInt, commandId: Int64, commandType: AgentCommand.CommandType, params: [String: Any]?) {
        guard var command = commandsById[commandId],
              var state = devicesById[deviceInternalId] else {
            return
        }

        let now = Date()
        command = AgentCommand(
            id: command.id,
            deviceId: command.deviceId,
            commandType: command.commandType,
            commandParams: command.commandParams,
            encryptedPayload: command.encryptedPayload,
            isEncrypted: command.isEncrypted,
            status: AgentCommand.Status.success.rawValue,
            result: demoResult(for: commandType, params: params, hostname: state.hostname),
            errorMessage: "",
            createdBy: command.createdBy,
            createdAt: command.createdAt,
            updatedAt: now,
            executedAt: now
        )
        commandsById[commandId] = command

        if commandType == .message,
           let agentId = params?["agent_id"] as? String,
           let agentIndex = state.agents.firstIndex(where: { $0.id == agentId }) {
            state.agents[agentIndex].lastActivityAt = now
            state.agents[agentIndex].online = true
            state.agents[agentIndex].unreadCount += 1
            devicesById[deviceInternalId] = state
        } else {
            state.updatedAt = now
            devicesById[deviceInternalId] = state
        }

        publishChanges()
    }

    private func demoResult(for commandType: AgentCommand.CommandType, params: [String: Any]?, hostname: String) -> String {
        switch commandType {
        case .status:
            return "演示设备 \(hostname) 运行正常\nGateway: online\nAgents: 2 在线"
        case .gateway:
            let action = params?["action"] as? String ?? "status"
            return "Gateway 演示结果：\(action) 已完成"
        case .config:
            let action = params?["action"] as? String ?? "show"
            return "配置演示结果：\(action) 已完成"
        case .logs:
            return "[demo] tail -n 50 logs\n[demo] gateway ready\n[demo] agents healthy"
        case .doctor:
            return "诊断完成，未发现严重问题。"
        case .probe:
            return "网络连通性正常，演示节点可达。"
        case .sessions:
            return "default: MiniMax-M2.5\nplanner: DeepSeek-V4"
        case .security:
            return "安全检查通过，未发现高风险配置。"
        case .start:
            return "演示模式：服务已启动"
        case .stop:
            return "演示模式：服务已停止"
        case .restart:
            return "演示模式：服务已重启"
        case .update:
            return "演示模式：当前已是最新版本"
        case .agents:
            return "default\nplanner"
        case .message:
            let content = params?["message"] as? String ?? ""
            return demoReply(for: content)
        }
    }

    private func demoReply(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "已收到空消息，这是演示回复。"
        }
        if trimmed.contains("你好") || trimmed.lowercased().contains("hello") {
            return "你好，这是爪群演示账号的模拟回复。"
        }
        if trimmed.contains("状态") {
            return "演示设备状态正常，CPU 约 22%，内存约 58%。"
        }
        return "已收到：\(trimmed)\n这是演示模式下的本地模拟回复，不会操作真实设备。"
    }

    private func makeDevice(from state: DeviceState) -> Device {
        let openClawInfo = OpenClawInfo(
            overview: state.overview,
            agents: state.agents.map { agent in
                OpenClawAgent(
                    id: agent.id,
                    name: agent.name,
                    sessions: nil,
                    active: agent.online ? "now" : "30m",
                    bootstrap: nil,
                    sessionModel: agent.sessionModel,
                    sessionTokens: agent.sessionTokens,
                    agentUnreadCount: agent.unreadCount,
                    agentOnline: agent.online
                )
            },
            channels: nil,
            bindings: nil,
            model: state.agents.first?.sessionModel,
            diagnosis: nil
        )

        let extraData = try? JSONEncoder().encode(openClawInfo)
        let unreadCount = state.agents.reduce(0) { $0 + $1.unreadCount }

        return Device(
            id: state.id,
            deviceId: state.deviceId,
            nodeId: state.nodeId,
            hostname: state.hostname,
            macAddress: state.macAddress,
            osVersion: state.osVersion,
            cpuModel: state.cpuModel,
            cpuCores: state.cpuCores,
            memoryTotal: state.memoryTotal,
            diskTotal: state.diskTotal,
            agentVersion: state.agentVersion,
            status: state.status,
            lastHeartbeatAt: state.lastHeartbeatAt,
            registeredAt: state.registeredAt,
            createdAt: state.registeredAt,
            updatedAt: state.updatedAt,
            extraData: extraData.flatMap { String(data: $0, encoding: .utf8) },
            latestMetric: state.metrics.sorted { $0.metricTime < $1.metricTime }.last,
            agentUnreadCount: unreadCount
        )
    }

    private func buildPrimaryDevice(now: Date) -> DeviceState {
        let metrics = stride(from: 9, through: 0, by: -1).enumerated().map { index, offset -> SystemMetric in
            let time = Calendar.current.date(byAdding: .minute, value: -offset * 3, to: now) ?? now
            return SystemMetric(
                id: UInt(index + 1),
                deviceId: 101,
                metricTime: time,
                cpuUsage: Double(18 + index * 2),
                memoryUsage: 56.0 + Double(index),
                memoryUsed: Int64(18_400_000_000 + index * 200_000_000),
                memoryAvailable: Int64(13_600_000_000 - index * 180_000_000),
                diskUsage: 62.0,
                diskUsed: 320_000_000_000,
                diskAvailable: 190_000_000_000,
                networkIn: Int64(50_000 + index * 1_500),
                networkOut: Int64(32_000 + index * 1_100),
                loadAverage1: 1.2,
                loadAverage5: 1.1,
                loadAverage15: 0.9,
                processCount: 218,
                createdAt: time
            )
        }

        return DeviceState(
            id: 101,
            deviceId: "demo-device-001",
            nodeId: "demo-node-001",
            hostname: "审核演示设备",
            macAddress: "AA:BB:CC:DD:EE:01",
            osVersion: "macOS 26.1",
            cpuModel: "Apple M4 Pro",
            cpuCores: 12,
            memoryTotal: 32_000_000_000,
            diskTotal: 512_000_000_000,
            agentVersion: "1.0.0-demo",
            status: Device.Status.online.rawValue,
            lastHeartbeatAt: now,
            registeredAt: Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now,
            updatedAt: now,
            overview: OpenClawOverview(
                version: "2026.3.1",
                os: "macOS",
                node: "运行正常",
                config: "openclaw.json",
                dashboard: "已启用",
                tailscale: nil,
                channel: "stable",
                update: "已最新",
                gateway: "online",
                gatewaySelf: nil,
                gatewayService: nil,
                nodeService: nil,
                agentsSummary: "2 在线"
            ),
            agents: [
                AgentState(id: "default", name: "default", online: true, unreadCount: 0, sessionModel: "MiniMax-M2.5", sessionTokens: "14k / 200k", lastActivityAt: Calendar.current.date(byAdding: .minute, value: -2, to: now)),
                AgentState(id: "planner", name: "planner", online: true, unreadCount: 1, sessionModel: "DeepSeek-V4", sessionTokens: "9k / 128k", lastActivityAt: Calendar.current.date(byAdding: .minute, value: -6, to: now)),
            ],
            metrics: metrics,
            skills: [
                SkillItem(id: 1, deviceId: 101, skillName: "web-search", skillVersion: "1.2.0", enabled: true, lastUsedAt: Calendar.current.date(byAdding: .hour, value: -1, to: now)),
                SkillItem(id: 2, deviceId: 101, skillName: "calendar", skillVersion: "1.0.4", enabled: true, lastUsedAt: Calendar.current.date(byAdding: .hour, value: -5, to: now)),
                SkillItem(id: 3, deviceId: 101, skillName: "local-files", skillVersion: "0.9.3", enabled: true, lastUsedAt: Calendar.current.date(byAdding: .day, value: -1, to: now)),
            ]
        )
    }

    private func buildOfflineDevice(now: Date) -> DeviceState {
        let heartbeat = Calendar.current.date(byAdding: .hour, value: -3, to: now)
        return DeviceState(
            id: 102,
            deviceId: "demo-device-002",
            nodeId: "demo-node-002",
            hostname: "异常演示设备",
            macAddress: "AA:BB:CC:DD:EE:02",
            osVersion: "macOS 15.5",
            cpuModel: "Apple M3",
            cpuCores: 8,
            memoryTotal: 16_000_000_000,
            diskTotal: 256_000_000_000,
            agentVersion: "1.0.0-demo",
            status: Device.Status.offline.rawValue,
            lastHeartbeatAt: heartbeat,
            registeredAt: Calendar.current.date(byAdding: .day, value: -8, to: now) ?? now,
            updatedAt: heartbeat ?? now,
            overview: OpenClawOverview(
                version: "2026.3.0",
                os: "macOS",
                node: "离线",
                config: "openclaw.json",
                dashboard: "未连接",
                tailscale: nil,
                channel: "stable",
                update: "可更新",
                gateway: "offline",
                gatewaySelf: nil,
                gatewayService: nil,
                nodeService: nil,
                agentsSummary: "0 在线"
            ),
            agents: [
                AgentState(id: "ops", name: "ops", online: false, unreadCount: 0, sessionModel: "DeepSeek-V4", sessionTokens: "--", lastActivityAt: Calendar.current.date(byAdding: .day, value: -1, to: now)),
            ],
            metrics: [],
            skills: []
        )
    }

    private func seedCommandHistory(now: Date) {
        let commands: [AgentCommand] = [
            AgentCommand(
                id: 901,
                deviceId: "demo-device-001",
                commandType: AgentCommand.CommandType.status.rawValue,
                commandParams: nil,
                encryptedPayload: nil,
                isEncrypted: false,
                status: AgentCommand.Status.success.rawValue,
                result: "演示设备运行正常\nGateway: online\nAgents: 2 在线",
                errorMessage: "",
                createdBy: "demo",
                createdAt: Calendar.current.date(byAdding: .minute, value: -35, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .minute, value: -35, to: now) ?? now,
                executedAt: Calendar.current.date(byAdding: .minute, value: -35, to: now) ?? now
            ),
            AgentCommand(
                id: 902,
                deviceId: "demo-device-001",
                commandType: AgentCommand.CommandType.message.rawValue,
                commandParams: [
                    "agent_id": AnyCodable("planner"),
                    "agent_name": AnyCodable("planner"),
                    "message": AnyCodable("帮我总结今天的待办"),
                    "input_type": AnyCodable("text"),
                ],
                encryptedPayload: nil,
                isEncrypted: false,
                status: AgentCommand.Status.success.rawValue,
                result: "今天有 3 项待办：审核设备状态、检查离线告警、处理命令结果。",
                errorMessage: "",
                createdBy: "demo",
                createdAt: Calendar.current.date(byAdding: .minute, value: -20, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .minute, value: -20, to: now) ?? now,
                executedAt: Calendar.current.date(byAdding: .minute, value: -20, to: now) ?? now
            ),
            AgentCommand(
                id: 903,
                deviceId: "demo-device-001",
                commandType: AgentCommand.CommandType.gateway.rawValue,
                commandParams: ["action": AnyCodable("status")],
                encryptedPayload: nil,
                isEncrypted: false,
                status: AgentCommand.Status.success.rawValue,
                result: "Gateway 演示结果：status 已完成",
                errorMessage: "",
                createdBy: "demo",
                createdAt: Calendar.current.date(byAdding: .minute, value: -12, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .minute, value: -12, to: now) ?? now,
                executedAt: Calendar.current.date(byAdding: .minute, value: -12, to: now) ?? now
            ),
            AgentCommand(
                id: 904,
                deviceId: "demo-device-002",
                commandType: AgentCommand.CommandType.status.rawValue,
                commandParams: nil,
                encryptedPayload: nil,
                isEncrypted: false,
                status: AgentCommand.Status.failed.rawValue,
                result: "",
                errorMessage: "设备离线，命令未执行",
                createdBy: "demo",
                createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now,
                executedAt: Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now
            ),
        ]

        for command in commands {
            commandsById[command.id] = command
            commandOrder.append(command.id)
        }
        nextCommandId = (commandOrder.max() ?? 1_000) + 1
    }
}
