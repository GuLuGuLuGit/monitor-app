import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.6), radius: 3)

            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

extension StatusBadge {
    static func deviceStatus(_ status: Int8) -> StatusBadge {
        switch status {
        case 1:  StatusBadge(text: "在线", color: AppColors.success)
        case 0:  StatusBadge(text: "离线", color: AppColors.error)
        case -1: StatusBadge(text: "禁用", color: AppColors.disabled)
        default: StatusBadge(text: "未知", color: AppColors.textSecondary)
        }
    }

    static func commandStatus(_ status: Int8) -> StatusBadge {
        let label = AgentCommand.Status(rawValue: status)?.label ?? "未知"
        let color = Color.commandStatusColor(status)
        return StatusBadge(text: label, color: color)
    }
}
