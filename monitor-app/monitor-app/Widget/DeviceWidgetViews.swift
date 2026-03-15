import SwiftUI

// Small Widget - Device count summary
struct DeviceWidgetSmallView: View {
    let entry: WidgetDeviceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "3b82f6"))
                Text("灵控")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "7a8ba8"))
            }

            Spacer()

            Text("\(entry.onlineDevices)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "00e5a0"))

            Text("在线")
                .font(.caption2)
                .foregroundStyle(Color(hex: "7a8ba8"))

            HStack(spacing: 12) {
                Label("\(entry.offlineDevices)", systemImage: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "ff4d6a"))
                Label("\(entry.totalDevices)", systemImage: "desktopcomputer")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "7a8ba8"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "060a1a"))
    }
}

// Medium Widget - Device count + recent list
struct DeviceWidgetMediumView: View {
    let entry: WidgetDeviceEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Summary
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(Color(hex: "3b82f6"))

                Spacer()

                HStack(spacing: 2) {
                    Text("\(entry.onlineDevices)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "00e5a0"))
                    Text("/\(entry.totalDevices)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "7a8ba8"))
                }

                Text("在线")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "7a8ba8"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Device list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.recentDevices.prefix(4), id: \.hostname) { device in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(device.status == 1 ? Color(hex: "00e5a0") : Color(hex: "ff4d6a"))
                            .frame(width: 6, height: 6)
                        Text(device.hostname)
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "e2e8f0"))
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(hex: "060a1a"))
    }
}

// Large Widget - Full device overview
struct DeviceWidgetLargeView: View {
    let entry: WidgetDeviceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(Color(hex: "3b82f6"))
                Text("灵控")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "f1f5f9"))
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "7a8ba8"))
            }

            // Stats row
            HStack(spacing: 0) {
                widgetStat(value: entry.totalDevices, label: "总计", color: Color(hex: "3b82f6"))
                widgetStat(value: entry.onlineDevices, label: "在线", color: Color(hex: "00e5a0"))
                widgetStat(value: entry.offlineDevices, label: "离线", color: Color(hex: "ff4d6a"))
                widgetStat(value: entry.disabledDevices, label: "禁用", color: Color(hex: "5a5e70"))
            }
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Device list
            Text("最近设备")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color(hex: "7a8ba8"))

            ForEach(entry.recentDevices.prefix(5), id: \.hostname) { device in
                HStack(spacing: 8) {
                    Circle()
                        .fill(device.status == 1 ? Color(hex: "00e5a0") : Color(hex: "ff4d6a"))
                        .frame(width: 8, height: 8)
                        .shadow(color: (device.status == 1 ? Color(hex: "00e5a0") : Color(hex: "ff4d6a")).opacity(0.5), radius: 3)

                    Text(device.hostname)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "e2e8f0"))

                    Spacer()

                    if let lastSeen = device.lastSeen {
                        Text(lastSeen.relativeString)
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "7a8ba8"))
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(hex: "060a1a"))
    }

    private func widgetStat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: "7a8ba8"))
        }
        .frame(maxWidth: .infinity)
    }
}
