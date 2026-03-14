import Foundation
import Observation

@Observable
@MainActor
final class DeviceDetailViewModel {
    let deviceId: UInt

    private(set) var device: Device?
    private(set) var metrics: [SystemMetric] = []
    private(set) var openClawInfo: OpenClawInfo?
    private(set) var skills: [SkillItem] = []
    private(set) var skillTotal: Int = 0
    private(set) var isLoadingAgents = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var refreshTimer: Timer?
    private var lastAgentsRequestAt: Date?

    init(deviceId: UInt) {
        self.deviceId = deviceId
    }

    func load() async {
        isLoading = device == nil
        errorMessage = nil

        do {
            let d: Device = try await APIClient.shared.request(.device(id: deviceId))
            device = d

            if let extraJson = d.extraData, let data = extraJson.data(using: .utf8) {
                openClawInfo = Self.parseOpenClawInfo(data)
            }

            await ensureAgentsLoaded()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private static func parseOpenClawInfo(_ data: Data) -> OpenClawInfo? {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(OpenClawInfo.self, from: data)
        } catch {
            print("[OpenClawInfo] decode error: \(error)")
            // Fallback: try to extract agents manually from raw JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return OpenClawInfo.fromRawJSON(json)
            }
            return nil
        }
    }

    func ensureAgentsLoaded(force: Bool = false) async {
        guard let device else { return }
        if !force {
            if (openClawInfo?.agents ?? []).isEmpty == false { return }
            if let lastAgentsRequestAt, Date().timeIntervalSince(lastAgentsRequestAt) < 60 { return }
        }

        lastAgentsRequestAt = Date()
        isLoadingAgents = true
        defer { isLoadingAgents = false }

        do {
            let request = CreateCommandRequest(
                deviceId: device.deviceId,
                commandType: AgentCommand.CommandType.agents.rawValue,
                commandParams: nil,
                isEncrypted: false
            )
            let command: AgentCommand = try await APIClient.shared.request(.createCommand, body: request)
            guard let latest = try await pollCommand(command.id), latest.commandStatus == .success else {
                return
            }
            let agents = OpenClawInfo.parseAgentsResult(latest.result)
            guard !agents.isEmpty else { return }
            mergeAgents(agents)
        } catch {
            // Non-critical: keep overview-only UI if agent list fetch fails.
        }
    }

    private func pollCommand(_ id: Int64) async throws -> AgentCommand? {
        for _ in 0..<10 {
            let command: AgentCommand = try await APIClient.shared.request(.command(id: id))
            if command.status != AgentCommand.Status.pending.rawValue &&
                command.status != AgentCommand.Status.running.rawValue {
                return command
            }
            try await Task.sleep(for: .seconds(1))
        }
        return try await APIClient.shared.request(.command(id: id))
    }

    private func mergeAgents(_ agents: [OpenClawAgent]) {
        let current = openClawInfo
        openClawInfo = OpenClawInfo(
            overview: current?.overview,
            agents: agents,
            channels: current?.channels,
            bindings: current?.bindings,
            model: current?.model,
            diagnosis: current?.diagnosis
        )
    }

    func loadSkills() async {
        do {
            let result: SkillListResponse = try await APIClient.shared.request(
                .skills,
                queryItems: [
                    URLQueryItem(name: "device_id", value: "\(deviceId)"),
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "page_size", value: "100"),
                ]
            )
            skills = result.items
            skillTotal = result.pagination?.total ?? result.items.count
        } catch {
            // Skills are non-critical
        }
    }

    func loadMetrics() async {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        do {
            let result: [SystemMetric] = try await APIClient.shared.request(
                .metrics,
                queryItems: [
                    URLQueryItem(name: "device_id", value: "\(deviceId)"),
                    URLQueryItem(name: "start_time", value: formatter.string(from: yesterday)),
                    URLQueryItem(name: "end_time", value: formatter.string(from: now)),
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "page_size", value: "288"),
                ]
            )
            metrics = result.sorted { $0.metricTime < $1.metricTime }
        } catch {
            // Metrics are non-critical, just skip
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.detailRefreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.load()
                await self.loadMetrics()
                await self.loadSkills()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct CreateCommandRequest: Encodable {
    let deviceId: String
    let commandType: String
    let commandParams: [String: AnyCodable]?
    let isEncrypted: Bool

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case commandType = "command_type"
        case commandParams = "command_params"
        case isEncrypted = "is_encrypted"
    }
}
