import Foundation
import Observation

@Observable
@MainActor
final class AgentMessageClient {
    private(set) var latestEvent: AgentMessageEvent?
    private(set) var isConnected = false

    private var wsTask: URLSessionWebSocketTask?
    private var deviceId: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    func connect(deviceId: String) async {
        self.deviceId = deviceId
        reconnectAttempts = 0

        let token = await KeychainStore.shared.getToken()
        connectWebSocket(deviceId: deviceId, token: token)
    }

    func disconnect() {
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        isConnected = false
    }

    private func connectWebSocket(deviceId: String, token: String?) {
        guard let token else { return }
        let urlString = "\(AppConfig.wsBaseURL)/admin/ws/agents/\(deviceId)/messages?token=\(token)"
        guard let url = URL(string: urlString) else { return }

        wsTask = URLSession.shared.webSocketTask(with: url)
        wsTask?.resume()
        isConnected = true
        receiveMessage()
    }

    private func receiveMessage() {
        wsTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(.string(let text)):
                    if let data = text.data(using: .utf8),
                       let event = try? JSONDecoder.api.decode(AgentMessageEvent.self, from: data) {
                        self.latestEvent = event
                    }
                    self.receiveMessage()

                case .success(.data(let data)):
                    if let event = try? JSONDecoder.api.decode(AgentMessageEvent.self, from: data) {
                        self.latestEvent = event
                    }
                    self.receiveMessage()

                case .failure:
                    self.isConnected = false
                    await self.scheduleReconnect()

                @unknown default:
                    self.receiveMessage()
                }
            }
        }
    }

    private func scheduleReconnect() async {
        guard reconnectAttempts < maxReconnectAttempts, let deviceId else { return }
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 3.0, 30.0)

        try? await Task.sleep(for: .seconds(delay))
        guard !isConnected else { return }
        let token = await KeychainStore.shared.getToken()
        connectWebSocket(deviceId: deviceId, token: token)
    }
}

struct AgentMessageEvent: Decodable, Equatable {
    let deviceId: String
    let agentId: String
    let commandId: Int64
    let role: String
    let content: String
    let status: Int8
    let inputType: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case agentId = "agent_id"
        case commandId = "command_id"
        case role, content, status
        case inputType = "input_type"
        case createdAt = "created_at"
    }
}
