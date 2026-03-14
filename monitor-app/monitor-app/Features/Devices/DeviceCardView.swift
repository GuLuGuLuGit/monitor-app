import SwiftUI

struct DeviceCardView: View {
    let device: Device
    var latestMetric: SystemMetric? = nil
    var unreadCount: Int = 0

    private var effectiveLatestMetric: SystemMetric? {
        latestMetric ?? device.latestMetric
    }

    private var openClawInfo: OpenClawInfo? {
        OpenClawInfo.parse(from: device.extraData)
    }

    private var agentCount: Int {
        openClawInfo?.agents?.count ?? 0
    }

    private var onlineAgentCount: Int {
        (openClawInfo?.agents ?? []).filter(isAgentOnline).count
    }

    private var priority: (label: String, color: Color) {
        if device.status != 1 { return ("异常", AppColors.error) }
        if agentCount == 0 || onlineAgentCount == 0 { return ("关注", AppColors.warning) }
        return ("正常", AppColors.success)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.primary.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: deviceIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.primary)

                    Circle()
                        .fill(Color.deviceStatusColor(device.status))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.hostname)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(device.osVersion)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusBadge.deviceStatus(device.status)
                    statusChip(priority.label, color: priority.color)
                    if unreadCount > 0 {
                        statusChip("未读 \(unreadCount)", color: AppColors.error)
                    }
                }
            }

            HStack(spacing: 8) {
                signalPill(title: "OpenClaw", value: openClawInfo?.overview?.version ?? device.agentVersion, detail: openClawInfo?.model ?? "待模型")
                signalPill(title: "Agents", value: "\(agentCount)", detail: agentCount > 0 ? "\(onlineAgentCount) 在线" : (openClawInfo?.overview?.agentsSummary ?? "待上报"))
            }

            HStack(spacing: 8) {
                statusChip("心跳 \(device.lastHeartbeatAt?.relativeString ?? "暂无")", color: device.isOnline ? AppColors.success : AppColors.disabled)
            }

            VStack(spacing: 10) {
                if let metric = effectiveLatestMetric, device.isOnline {
                    usageRow(title: "CPU", usage: metric.cpuUsage, detail: device.formattedCPU)
                    usageRow(title: "内存", usage: metric.memoryUsage, detail: "\(formattedBytes(metric.memoryUsed)) / \(device.formattedMemory)")
                    usageRow(title: "磁盘", usage: metric.diskUsage, detail: "\(formattedBytes(metric.diskUsed)) / \(device.formattedDisk)")
                } else {
                    placeholderUsageRow(title: "CPU")
                    placeholderUsageRow(title: "内存")
                    placeholderUsageRow(title: "磁盘")
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .cardStyle()
    }

    private func signalPill(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.primary.opacity(0.9))
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textTitle)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.white.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                .stroke(AppColors.borderColor, lineWidth: 1)
        )
    }

    private func usageRow(title: String, usage: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text("\(Int(usage.rounded()))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(usageColor(usage))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.22))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(usageColor(usage))
                        .frame(width: proxy.size.width * min(max(usage, 0), 100) / 100)
                }
            }
            .frame(height: 8)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
    }

    private func placeholderUsageRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 28, alignment: .leading)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.22))
                .frame(height: 8)
            Text("--")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func statusChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .lineLimit(1)
    }

    private var deviceIcon: String {
        let os = device.osVersion.lowercased()
        if os.contains("mac") { return "laptopcomputer" }
        if os.contains("linux") { return "server.rack" }
        return "desktopcomputer"
    }

    private func usageColor(_ usage: Double) -> Color {
        usage > 80 ? AppColors.error : usage > 60 ? AppColors.warning : AppColors.success
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }

    private func isAgentOnline(_ agent: OpenClawAgent) -> Bool {
        agent.isLikelyOnline()
    }
}
