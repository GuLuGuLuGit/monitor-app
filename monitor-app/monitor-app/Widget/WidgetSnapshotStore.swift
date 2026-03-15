import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetSnapshot: Codable {
    let date: Date
    let totalDevices: Int
    let onlineDevices: Int
    let offlineDevices: Int
    let disabledDevices: Int
    let recentDevices: [WidgetSnapshotDevice]
    let abnormalDevices: [WidgetSnapshotAlert]
    let unreadDevices: [WidgetSnapshotUnread]

    static let empty = WidgetSnapshot(
        date: .now,
        totalDevices: 0,
        onlineDevices: 0,
        offlineDevices: 0,
        disabledDevices: 0,
        recentDevices: [],
        abnormalDevices: [],
        unreadDevices: []
    )
}

struct WidgetSnapshotDevice: Codable {
    let hostname: String
    let status: Int8
    let lastSeen: Date?
}

struct WidgetSnapshotAlert: Codable {
    let hostname: String
    let reason: String
    let status: Int8
    let lastSeen: Date?
}

struct WidgetSnapshotUnread: Codable {
    let hostname: String
    let unreadCount: Int
    let lastSeen: Date?
}

enum WidgetSnapshotStore {
    static let suiteName = "group.com.mayunfeng.monitor-app"
    static let key = "lingkong_widget_snapshot_v1"

    static func save(devices: [Device]) {
        let snapshot = buildSnapshot(from: devices)
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: key)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        defaults.removeObject(forKey: key)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static func buildSnapshot(from devices: [Device]) -> WidgetSnapshot {
        let sortedDevices = devices.sorted {
            ($0.lastHeartbeatAt ?? $0.registeredAt) > ($1.lastHeartbeatAt ?? $1.registeredAt)
        }

        let recentDevices = sortedDevices.prefix(5).map {
            WidgetSnapshotDevice(hostname: $0.hostname, status: $0.status, lastSeen: $0.lastHeartbeatAt)
        }

        let abnormalDevices = sortedDevices.compactMap { device -> WidgetSnapshotAlert? in
            guard let reason = abnormalReason(for: device) else { return nil }
            return WidgetSnapshotAlert(hostname: device.hostname, reason: reason, status: device.status, lastSeen: device.lastHeartbeatAt)
        }

        let unreadDevices = sortedDevices.compactMap { device -> WidgetSnapshotUnread? in
            let unread = device.agentUnreadCount ?? 0
            guard unread > 0 else { return nil }
            return WidgetSnapshotUnread(hostname: device.hostname, unreadCount: unread, lastSeen: device.lastHeartbeatAt)
        }

        return WidgetSnapshot(
            date: .now,
            totalDevices: devices.count,
            onlineDevices: devices.filter { $0.status == 1 }.count,
            offlineDevices: devices.filter { $0.status == 0 }.count,
            disabledDevices: devices.filter { $0.status < 0 }.count,
            recentDevices: Array(recentDevices),
            abnormalDevices: Array(abnormalDevices.prefix(6)),
            unreadDevices: Array(unreadDevices.prefix(6))
        )
    }

    private static func abnormalReason(for device: Device) -> String? {
        if device.status < 0 { return "已禁用" }
        if device.status == 0 { return "设备离线" }
        let info = OpenClawInfo.parse(from: device.extraData)
        let agents = info?.agents ?? []
        if agents.isEmpty {
            return "无 Agents"
        }
        if !agents.contains(where: { $0.isLikelyOnline() }) {
            return "无在线 Agent"
        }
        return nil
    }
}
