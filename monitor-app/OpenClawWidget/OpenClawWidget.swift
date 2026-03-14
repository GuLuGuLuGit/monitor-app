import WidgetKit
import SwiftUI

struct DeviceStatusEntry: TimelineEntry {
    let date: Date
    let onlineCount: Int
    let offlineCount: Int
    let totalCount: Int
    let disabledCount: Int
    let deviceNames: [(String, Bool)] // (hostname, isOnline)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DeviceStatusEntry {
        DeviceStatusEntry(date: .now, onlineCount: 2, offlineCount: 1, totalCount: 3, disabledCount: 0, deviceNames: [("MacBook-Pro", true), ("Mac-Mini", false)])
    }

    func getSnapshot(in context: Context, completion: @escaping (DeviceStatusEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeviceStatusEntry>) -> Void) {
        // Widget 每 15 分钟刷新一次
        let entry = placeholder(in: context)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct OpenClawWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                Text("OpenClaw")
                    .font(.caption2).fontWeight(.semibold)
            }
            .foregroundStyle(.secondary)
            Spacer()
            Text("\(entry.onlineCount)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            Text("在线")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    var mediumView: some View {
        HStack {
            smallView
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.deviceNames.prefix(4), id: \.0) { name, online in
                    HStack(spacing: 6) {
                        Circle().fill(online ? .green : .red).frame(width: 6, height: 6)
                        Text(name).font(.caption2).lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical)
        }
    }
}

struct OpenClawWidget: Widget {
    let kind = "OpenClawWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            OpenClawWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("OpenClaw 设备监控")
        .description("查看设备状态")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
