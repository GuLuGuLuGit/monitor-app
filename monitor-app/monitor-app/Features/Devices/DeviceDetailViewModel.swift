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
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var refreshTimer: Timer?

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
        } catch {
            metrics = []
            print("[DeviceDetail] load metrics failed for device \(deviceId): \(error)")
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
