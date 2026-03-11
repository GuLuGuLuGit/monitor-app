import Foundation

struct WidgetDeviceEntry {
    let date: Date
    let totalDevices: Int
    let onlineDevices: Int
    let offlineDevices: Int
    let disabledDevices: Int
    let recentDevices: [WidgetDeviceItem]
    let isPlaceholder: Bool

    static let placeholder = WidgetDeviceEntry(
        date: .now,
        totalDevices: 3,
        onlineDevices: 2,
        offlineDevices: 1,
        disabledDevices: 0,
        recentDevices: [
            WidgetDeviceItem(hostname: "MacBook-Pro", status: 1, lastSeen: .now),
            WidgetDeviceItem(hostname: "Mac-Mini", status: 1, lastSeen: .now),
            WidgetDeviceItem(hostname: "Server-NAS", status: 0, lastSeen: .now.addingTimeInterval(-3600)),
        ],
        isPlaceholder: true
    )
}

struct WidgetDeviceItem {
    let hostname: String
    let status: Int8
    let lastSeen: Date?
}

actor WidgetDataFetcher {
    static let shared = WidgetDataFetcher()

    func fetchDashboard() async -> WidgetDeviceEntry {
        guard let token = await KeychainStore.shared.getToken(), !token.isEmpty else {
            return WidgetDeviceEntry(
                date: .now, totalDevices: 0, onlineDevices: 0, offlineDevices: 0, disabledDevices: 0,
                recentDevices: [], isPlaceholder: false
            )
        }

        do {
            let dashboard: DashboardData = try await APIClient.shared.request(.dashboard)
            let summary = dashboard.deviceSummary
            let devices = dashboard.recentDevices.prefix(5).map { device in
                WidgetDeviceItem(hostname: device.hostname, status: device.status, lastSeen: device.lastHeartbeatAt)
            }

            return WidgetDeviceEntry(
                date: .now,
                totalDevices: Int(summary.total),
                onlineDevices: Int(summary.online),
                offlineDevices: Int(summary.offline),
                disabledDevices: Int(summary.disabled),
                recentDevices: Array(devices),
                isPlaceholder: false
            )
        } catch {
            return WidgetDeviceEntry(
                date: .now, totalDevices: 0, onlineDevices: 0, offlineDevices: 0, disabledDevices: 0,
                recentDevices: [], isPlaceholder: false
            )
        }
    }
}
