import Foundation
import Observation

@Observable
@MainActor
final class DeviceDetailViewModel {
    let deviceId: UInt

    private(set) var device: Device?
    private(set) var metrics: [SystemMetric] = []
    private(set) var openClawInfo: OpenClawInfo?
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
                openClawInfo = try? JSONDecoder.api.decode(OpenClawInfo.self, from: data)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
