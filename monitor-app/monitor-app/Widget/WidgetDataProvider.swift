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
