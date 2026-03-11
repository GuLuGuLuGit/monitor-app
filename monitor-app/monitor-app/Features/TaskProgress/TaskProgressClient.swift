import Foundation
import Observation

@Observable
@MainActor
final class TaskProgressClient {
    private(set) var latestProgress: TaskProgress?
    private(set) var progressHistory: [TaskProgress] = []
    private(set) var isConnected = false
    private(set) var errorMessage: String?

    private var wsTask: URLSessionWebSocketTask?
    private var commandId: Int64?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    func connect(commandId: Int64) async {
        self.commandId = commandId
        reconnectAttempts = 0

        await loadHistory(commandId: commandId)

        let token = await KeychainStore.shared.getToken()
        connectWebSocket(commandId: commandId, token: token)
    }

    func disconnect() {
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        isConnected = false
    }

    private func connectWebSocket(commandId: Int64, token: String?) {
        guard let token else {
            errorMessage = "未登录"
            return
        }

        let urlString = "\(AppConfig.wsBaseURL)/admin/ws/tasks/\(commandId)/progress?token=\(token)"
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
                       let progress = try? JSONDecoder.api.decode(TaskProgress.self, from: data) {
                        self.latestProgress = progress
                        self.progressHistory.append(progress)
                    }
                    self.receiveMessage()

                case .success(.data(let data)):
                    if let progress = try? JSONDecoder.api.decode(TaskProgress.self, from: data) {
                        self.latestProgress = progress
                        self.progressHistory.append(progress)
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
        guard reconnectAttempts < maxReconnectAttempts, let commandId else { return }
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 3.0, 30.0)

        try? await Task.sleep(for: .seconds(delay))
        guard !isConnected else { return }
        let token = await KeychainStore.shared.getToken()
        connectWebSocket(commandId: commandId, token: token)
    }

    private func loadHistory(commandId: Int64) async {
        do {
            let history: [TaskProgress] = try await APIClient.shared.request(.taskProgress(id: commandId))
            progressHistory = history.sorted { $0.createdAt < $1.createdAt }
            latestProgress = progressHistory.last
        } catch {}
    }
}
