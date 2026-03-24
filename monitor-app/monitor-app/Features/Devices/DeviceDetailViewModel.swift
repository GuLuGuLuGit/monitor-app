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
    private(set) var recentAgentActivity: [String: Date] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isShowingStaleData = false

    private var refreshTimer: Timer?
    private var didRetryMissingMetric = false

    init(device: Device) {
        self.deviceId = device.id
        self.device = device
        if let extraJson = device.extraData, let data = extraJson.data(using: .utf8) {
            self.openClawInfo = Self.parseOpenClawInfo(data)
        }
    }

    func load() async {
        isLoading = device == nil
        errorMessage = nil

        do {
            let d: Device
            if AuthManager.shared.isDemoMode {
                guard let demoDevice = DemoModeStore.shared.device(id: deviceId) else {
                    throw APIError.server(code: 500, message: "演示设备不存在")
                }
                d = demoDevice
            } else {
                d = try await APIClient.shared.request(.device(id: deviceId))
            }
            device = d
            isShowingStaleData = false

            if let extraJson = d.extraData, let data = extraJson.data(using: .utf8) {
                openClawInfo = Self.parseOpenClawInfo(data)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isShowingStaleData = device != nil
        } catch {
            errorMessage = error.localizedDescription
            isShowingStaleData = device != nil
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

    func loadSkills() async {
        do {
            if AuthManager.shared.isDemoMode {
                let result = DemoModeStore.shared.skills(deviceId: deviceId)
                skills = result
                skillTotal = result.count
            } else {
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
            }
        } catch {
            if skills.isEmpty {
                skillTotal = 0
            }
        }
    }

    func loadMetrics() async {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        do {
            if AuthManager.shared.isDemoMode {
                metrics = DemoModeStore.shared.metrics(deviceId: deviceId).sorted { $0.metricTime < $1.metricTime }
            } else {
                let result: PagedData<SystemMetric> = try await APIClient.shared.request(
                    .metrics,
                    queryItems: [
                        URLQueryItem(name: "device_id", value: "\(deviceId)"),
                        URLQueryItem(name: "start_time", value: formatter.string(from: yesterday)),
                        URLQueryItem(name: "end_time", value: formatter.string(from: now)),
                        URLQueryItem(name: "page", value: "1"),
                        URLQueryItem(name: "page_size", value: "288"),
                    ]
                )
                metrics = result.items.sorted { $0.metricTime < $1.metricTime }
            }
            if !metrics.isEmpty || device?.latestMetric != nil {
                didRetryMissingMetric = false
            }
        } catch {
            print("[DeviceDetail] load metrics failed for device \(deviceId): \(error)")
        }
    }

    func loadRecentAgentActivity() async {
        guard let deviceId = device?.deviceId, !deviceId.isEmpty else { return }

        do {
            let latestByAgent: [String: Date]
            if AuthManager.shared.isDemoMode {
                latestByAgent = DemoModeStore.shared.recentAgentActivity(deviceId: deviceId)
            } else {
                let result: CommandListResponse = try await APIClient.shared.request(
                    .commands,
                    queryItems: [
                        URLQueryItem(name: "device_id", value: deviceId),
                        URLQueryItem(name: "command_type", value: "openclaw_message"),
                        URLQueryItem(name: "page", value: "1"),
                        URLQueryItem(name: "page_size", value: "50"),
                    ]
                )

                var map: [String: Date] = [:]
                for cmd in result.commands {
                    guard let agentId = cmd.commandParams?["agent_id"]?.value as? String,
                          !agentId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        continue
                    }
                    let activityAt = cmd.executedAt ?? cmd.updatedAt
                    if let existing = map[agentId], existing >= activityAt {
                        continue
                    }
                    map[agentId] = activityAt
                }
                latestByAgent = map
            }
            recentAgentActivity = latestByAgent
        } catch {
            if recentAgentActivity.isEmpty {
                recentAgentActivity = [:]
            }
        }
    }

    func unreadCount(for agentId: String) -> Int {
        openClawInfo?.agents?.first(where: { $0.id == agentId })?.agentUnreadCount ?? 0
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.detailRefreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.load()
                await self.loadMetrics()
                await self.loadSkills()
                await self.loadRecentAgentActivity()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func clearError() {
        errorMessage = nil
    }
}


extension DeviceDetailViewModel {
    func reloadIfMissingMetric() async {
        guard let device, device.status == 1 else { return }
        guard metrics.isEmpty, device.latestMetric == nil, !didRetryMissingMetric else { return }
        didRetryMissingMetric = true
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await load()
        await loadMetrics()
    }
}
