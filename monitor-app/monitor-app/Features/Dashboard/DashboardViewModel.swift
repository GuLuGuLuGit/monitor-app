import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    private(set) var dashboardData: DashboardData?
    private(set) var taskStats: TaskStats?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var refreshTimer: Timer?

    func load() async {
        isLoading = dashboardData == nil
        errorMessage = nil

        do {
            async let dashboard: DashboardData = APIClient.shared.request(.dashboard)
            async let stats: TaskStats = APIClient.shared.request(.taskStats)
            let (d, s) = try await (dashboard, stats)
            dashboardData = d
            taskStats = s
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.load() }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
