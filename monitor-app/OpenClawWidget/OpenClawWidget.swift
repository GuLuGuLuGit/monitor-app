import WidgetKit
import SwiftUI

private enum WidgetKind {
    static let overview = "LingkongOverviewWidget"
    static let alerts = "LingkongAlertsWidget"
    static let unread = "LingkongUnreadWidget"
    static let suiteName = "group.com.mayunfeng.monitor-app"
    static let snapshotKey = "lingkong_widget_snapshot_v1"
}

private struct WidgetSnapshot: Codable {
    let date: Date
    let totalDevices: Int
    let onlineDevices: Int
    let offlineDevices: Int
    let disabledDevices: Int
    let recentDevices: [WidgetSnapshotDevice]
    let abnormalDevices: [WidgetSnapshotAlert]
    let unreadDevices: [WidgetSnapshotUnread]

    static let placeholder = WidgetSnapshot(
        date: .now,
        totalDevices: 6,
        onlineDevices: 4,
        offlineDevices: 1,
        disabledDevices: 1,
        recentDevices: [
            WidgetSnapshotDevice(hostname: "Mac mini", status: 1, lastSeen: .now),
            WidgetSnapshotDevice(hostname: "MacBook Pro", status: 0, lastSeen: .now.addingTimeInterval(-1800)),
            WidgetSnapshotDevice(hostname: "Studio", status: 1, lastSeen: .now.addingTimeInterval(-300)),
        ],
        abnormalDevices: [
            WidgetSnapshotAlert(hostname: "MacBook Pro", reason: "设备离线", status: 0, lastSeen: .now.addingTimeInterval(-1800)),
            WidgetSnapshotAlert(hostname: "Studio", reason: "无在线 Agent", status: 1, lastSeen: .now.addingTimeInterval(-300)),
        ],
        unreadDevices: [
            WidgetSnapshotUnread(hostname: "Mac mini", unreadCount: 3, lastSeen: .now.addingTimeInterval(-120)),
            WidgetSnapshotUnread(hostname: "Studio", unreadCount: 1, lastSeen: .now.addingTimeInterval(-600)),
        ]
    )
}

private struct WidgetSnapshotDevice: Codable {
    let hostname: String
    let status: Int8
    let lastSeen: Date?
}

private struct WidgetSnapshotAlert: Codable {
    let hostname: String
    let reason: String
    let status: Int8
    let lastSeen: Date?
}

private struct WidgetSnapshotUnread: Codable {
    let hostname: String
    let unreadCount: Int
    let lastSeen: Date?
}

private struct OverviewEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct AlertsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct UnreadEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private enum SnapshotLoader {
    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: WidgetKind.suiteName),
              let data = defaults.data(forKey: WidgetKind.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}

private struct OverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> OverviewEntry {
        OverviewEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (OverviewEntry) -> Void) {
        completion(OverviewEntry(date: .now, snapshot: SnapshotLoader.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OverviewEntry>) -> Void) {
        let entry = OverviewEntry(date: .now, snapshot: SnapshotLoader.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private struct AlertsProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlertsEntry {
        AlertsEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (AlertsEntry) -> Void) {
        completion(AlertsEntry(date: .now, snapshot: SnapshotLoader.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlertsEntry>) -> Void) {
        let entry = AlertsEntry(date: .now, snapshot: SnapshotLoader.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private struct UnreadProvider: TimelineProvider {
    func placeholder(in context: Context) -> UnreadEntry {
        UnreadEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UnreadEntry) -> Void) {
        completion(UnreadEntry(date: .now, snapshot: SnapshotLoader.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UnreadEntry>) -> Void) {
        let entry = UnreadEntry(date: .now, snapshot: SnapshotLoader.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private struct LingkongOverviewWidgetView: View {
    let entry: OverviewEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            largeView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(title: "设备状态")
            Spacer()
            Text("\(entry.snapshot.onlineDevices)/\(max(entry.snapshot.totalDevices, 1))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            Text("在线 / 总设备")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                miniStat("离线", value: entry.snapshot.offlineDevices, color: .red)
                miniStat("禁用", value: entry.snapshot.disabledDevices, color: .gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                header(title: "设备状态")
                HStack(spacing: 0) {
                    statBlock("总计", value: entry.snapshot.totalDevices, color: .blue)
                    statBlock("在线", value: entry.snapshot.onlineDevices, color: .green)
                    statBlock("离线", value: entry.snapshot.offlineDevices, color: .red)
                    statBlock("禁用", value: entry.snapshot.disabledDevices, color: .gray)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("最近设备")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(entry.snapshot.recentDevices.prefix(4), id: \.hostname) { device in
                    rowDot(device.status == 1 ? .green : .red, title: device.hostname, subtitle: device.lastSeen?.relativeString ?? "暂无")
                }
                Spacer()
            }
        }
        .padding()
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                header(title: "设备状态总览")
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                statBlock("总计", value: entry.snapshot.totalDevices, color: .blue)
                statBlock("在线", value: entry.snapshot.onlineDevices, color: .green)
                statBlock("离线", value: entry.snapshot.offlineDevices, color: .red)
                statBlock("禁用", value: entry.snapshot.disabledDevices, color: .gray)
            }
            Text("最近设备")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(entry.snapshot.recentDevices.prefix(5), id: \.hostname) { device in
                rowDot(device.status == 1 ? .green : .red, title: device.hostname, subtitle: device.lastSeen?.relativeString ?? "暂无")
            }
            Spacer()
        }
        .padding()
    }
}

private struct LingkongAlertsWidgetView: View {
    let entry: AlertsEntry
    @Environment(\.widgetFamily) private var family

    private var alerts: [WidgetSnapshotAlert] { entry.snapshot.abnormalDevices }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            largeView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(title: "异常设备")
            Spacer()
            Text("\(alerts.count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(alerts.isEmpty ? .green : .orange)
            Text(alerts.isEmpty ? "当前无异常" : (alerts.first?.hostname ?? "待处理"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                header(title: "异常设备")
                Spacer()
                Text("\(alerts.count) 台")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if alerts.isEmpty {
                emptyState("当前无异常")
            } else {
                ForEach(alerts.prefix(3), id: \.hostname) { alert in
                    rowDot(alert.status == 1 ? .orange : .red, title: alert.hostname, subtitle: alert.reason)
                }
            }
            Spacer()
        }
        .padding()
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                header(title: "异常设备")
                Spacer()
                Text("\(alerts.count) 台")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if alerts.isEmpty {
                emptyState("当前无异常")
            } else {
                ForEach(alerts.prefix(5), id: \.hostname) { alert in
                    HStack(spacing: 8) {
                        Circle().fill(alert.status == 1 ? .orange : .red).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.hostname)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(alert.reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if let lastSeen = alert.lastSeen {
                            Text(lastSeen.relativeString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}

private struct LingkongUnreadWidgetView: View {
    let entry: UnreadEntry
    @Environment(\.widgetFamily) private var family

    private var items: [WidgetSnapshotUnread] { entry.snapshot.unreadDevices }
    private var totalUnread: Int { items.reduce(0) { $0 + $1.unreadCount } }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            largeView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(title: "未读消息")
            Spacer()
            Text("\(totalUnread)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(totalUnread == 0 ? .green : .blue)
            Text(totalUnread == 0 ? "暂无未读" : "来自 \(items.count) 台设备")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                header(title: "未读消息")
                Spacer()
                Text("\(totalUnread) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if items.isEmpty {
                emptyState("暂无未读")
            } else {
                ForEach(items.prefix(3), id: \.hostname) { item in
                    HStack(spacing: 8) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        Text(item.hostname)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("未读 \(item.unreadCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                header(title: "未读消息")
                Spacer()
                Text("\(totalUnread) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if items.isEmpty {
                emptyState("暂无未读")
            } else {
                ForEach(items.prefix(5), id: \.hostname) { item in
                    HStack(spacing: 8) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.hostname)
                                .font(.caption)
                                .lineLimit(1)
                            Text("未读 \(item.unreadCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let lastSeen = item.lastSeen {
                            Text(lastSeen.relativeString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}

private extension View {
    func widgetShell() -> some View {
        self.containerBackground(.background, for: .widget)
    }
}

private func header(title: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.caption)
            .foregroundStyle(.blue)
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
    }
}

private func statBlock(_ title: String, value: Int, color: Color) -> some View {
    VStack(spacing: 2) {
        Text("\(value)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(color)
        Text(title)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
}

private func miniStat(_ title: String, value: Int, color: Color) -> some View {
    HStack(spacing: 4) {
        Circle().fill(color).frame(width: 6, height: 6)
        Text("\(title) \(value)")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

private func rowDot(_ color: Color, title: String, subtitle: String) -> some View {
    HStack(spacing: 8) {
        Circle().fill(color).frame(width: 8, height: 8)
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        Spacer()
    }
}

private func emptyState(_ title: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Spacer()
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
        Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

private extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

struct LingkongOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.overview, provider: OverviewProvider()) { entry in
            LingkongOverviewWidgetView(entry: entry)
                .widgetShell()
        }
        .configurationDisplayName("设备状态总览")
        .description("查看设备总数、在线状态和最近设备")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct LingkongAlertsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.alerts, provider: AlertsProvider()) { entry in
            LingkongAlertsWidgetView(entry: entry)
                .widgetShell()
        }
        .configurationDisplayName("异常设备")
        .description("优先查看离线、禁用或无在线 Agent 的设备")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct LingkongUnreadWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.unread, provider: UnreadProvider()) { entry in
            LingkongUnreadWidgetView(entry: entry)
                .widgetShell()
        }
        .configurationDisplayName("未读消息")
        .description("查看哪些设备有新的 Agent 回复")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
