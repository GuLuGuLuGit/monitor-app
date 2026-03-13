import SwiftUI

struct DeviceCardView: View {
    let device: Device
    var latestMetric: SystemMetric? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: deviceIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(Color.deviceStatusColor(device.status))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                    .shadow(color: Color.deviceStatusColor(device.status).opacity(0.5), radius: 3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.hostname)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let nodeId = device.nodeId {
                        Text(String(nodeId.prefix(8)))
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                            .monospaced()
                    }

                    Text(device.osVersion)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                if let heartbeat = device.lastHeartbeatAt {
                    Text(heartbeat.relativeString)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                }
            }

            Spacer()

            if let metric = latestMetric {
                HStack(spacing: 8) {
                    UsageRing(value: metric.cpuUsage, label: "CPU", color: cpuColor(metric.cpuUsage), size: 36)
                    UsageRing(value: metric.memoryUsage, label: "内存", color: memColor(metric.memoryUsage), size: 36)
                    UsageRing(value: metric.diskUsage, label: "磁盘", color: diskColor(metric.diskUsage), size: 36)
                }
            } else {
                StatusBadge.deviceStatus(device.status)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var deviceIcon: String {
        let os = device.osVersion.lowercased()
        if os.contains("mac") { return "laptopcomputer" }
        if os.contains("linux") { return "server.rack" }
        return "desktopcomputer"
    }

    private func cpuColor(_ usage: Double) -> Color {
        usage > 80 ? AppColors.error : usage > 50 ? AppColors.warning : AppColors.success
    }

    private func memColor(_ usage: Double) -> Color {
        usage > 85 ? AppColors.error : usage > 60 ? AppColors.warning : AppColors.cyan
    }

    private func diskColor(_ usage: Double) -> Color {
        usage > 90 ? AppColors.error : usage > 70 ? AppColors.warning : AppColors.primary
    }
}
