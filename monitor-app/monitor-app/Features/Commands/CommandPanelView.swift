import SwiftUI

struct CommandPanelView: View {
    let device: Device
    @State private var viewModel = CommandViewModel()
    @State private var showConfirm = false
    @State private var pendingCommand: AgentCommand.CommandType?
    @State private var pendingParams: [String: Any]?
    @State private var showParamSheet = false
    @State private var paramSheetType: AgentCommand.CommandType?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            controlIntro

            ForEach(AgentCommand.CommandGroup.allCases, id: \.rawValue) { group in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.label)
                                .font(.headline)
                                .foregroundStyle(AppColors.textTitle)
                            Text(groupDescription(group))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Text("\(group.types.count) 项")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.28))
                            .clipShape(Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(group.types.filter(\.isVisibleInCommandPanel), id: \.rawValue) { cmdType in
                            commandButton(cmdType)
                        }
                    }
                }
                .padding(18)
                .cardStyle()
            }

            if let msg = viewModel.successMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(AppColors.success)
                }
                .padding(.horizontal, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.errorMessage = nil
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.successMessage)
        .alert("确认执行", isPresented: $showConfirm) {
            Button("取消", role: .cancel) { pendingCommand = nil; pendingParams = nil }
            Button("确认") {
                guard let cmd = pendingCommand else { return }
                Task {
                    await viewModel.sendCommand(
                        deviceId: device.deviceId,
                        deviceInternalId: device.id,
                        commandType: cmd,
                        params: pendingParams
                    )
                }
                pendingCommand = nil
                pendingParams = nil
            }
        } message: {
            if let cmd = pendingCommand {
                Text("确定要对 \(device.hostname) 执行「\(cmd.label)」操作吗？")
            }
        }
        .sheet(isPresented: $showParamSheet) {
            if let cmdType = paramSheetType {
                ParamSheetView(commandType: cmdType) { params in
                    showParamSheet = false
                    pendingCommand = cmdType
                    pendingParams = params
                    showConfirm = true
                }
                .presentationDetents([.medium])
            }
        }
        .overlay {
            if viewModel.isSending {
                LoadingOverlay(message: "发送命令中...")
            }
        }
    }

    private var controlIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenClaw 控制台")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textTitle)
            Text("建议先执行状态查询、健康诊断和日志定位，再决定是否执行 restart、update、gateway 这类会影响运行面的操作。")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle()
    }

    private func groupDescription(_ group: AgentCommand.CommandGroup) -> String {
        switch group {
        case .control:
            return "直接控制 OpenClaw 运行面。危险动作前建议先确认当前状态。"
        case .diagnose:
            return "优先使用查询类命令定位问题，再决定是否执行控制动作。"
        case .manage:
            return "涉及配置、更新、会话和安全，建议在低干扰时段执行。"
        }
    }

    private func commandButton(_ type: AgentCommand.CommandType) -> some View {
        Button {
            if type.needsParams {
                paramSheetType = type
                showParamSheet = true
            } else {
                pendingCommand = type
                pendingParams = nil
                showConfirm = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(buttonColor(type).opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: type.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(buttonColor(type))
                    }
                    Spacer()
                    if type.needsParams {
                        Text("参数")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.25))
                            .clipShape(Capsule())
                    }
                }

                Text(type.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)

                Text(commandHint(type))
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .padding(14)
            .background(Color.white.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .stroke(AppColors.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSending)
    }

    private func commandHint(_ type: AgentCommand.CommandType) -> String {
        switch type {
        case .start: return "启动 OpenClaw 服务"
        case .stop: return "停止当前服务"
        case .restart: return "重启服务和关键依赖"
        case .gateway: return "查看或重启 Gateway"
        case .status: return "读取当前运行状态"
        case .doctor: return "执行健康诊断"
        case .probe: return "检查连通性与探针"
        case .logs: return "查看最近日志输出"
        case .config: return "读取或验证配置"
        case .update: return "检查并执行更新"
        case .sessions: return "查看或清理会话"
        case .security: return "执行安全审计"
        case .agents: return "读取 agent 列表"
        case .message: return "发送消息给 agent"
        }
    }

    private func buttonColor(_ type: AgentCommand.CommandType) -> Color {
        switch type {
        case .start: AppColors.success
        case .stop: AppColors.error
        case .restart, .gateway: AppColors.warning
        case .status, .doctor, .probe, .logs, .agents: AppColors.primary
        case .config, .update, .sessions, .security: AppColors.cyan
        case .message: AppColors.primary
        }
    }
}

private struct ParamSheetView: View {
    let commandType: AgentCommand.CommandType
    let onConfirm: ([String: Any]?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                switch commandType {
                case .gateway:
                    Section("Gateway 管理") {
                        paramRow("查看状态", params: ["action": "status"])
                        paramRow("健康检查", params: ["action": "health"])
                        paramRow("重启 Gateway", params: ["action": "restart"])
                    }
                case .logs:
                    Section("查看日志") {
                        paramRow("最近 50 行", params: ["lines": 50])
                        paramRow("最近 200 行", params: ["lines": 200])
                        paramRow("最近 500 行", params: ["lines": 500])
                    }
                case .update:
                    Section("版本更新") {
                        paramRow("检查更新", params: ["action": "check"])
                        paramRow("执行更新", params: ["action": "apply"])
                        paramRow("更新到 Beta", params: ["action": "apply", "channel": "beta"])
                    }
                case .sessions:
                    Section("会话管理") {
                        paramRow("查看会话列表", params: ["action": "list"])
                        paramRow("清理预览 (dry-run)", params: ["action": "cleanup", "dry_run": true])
                        paramRow("执行清理", params: ["action": "cleanup"])
                    }
                case .security:
                    Section("安全审计") {
                        paramRow("标准审计", params: [:])
                        paramRow("深度审计", params: ["deep": true])
                    }
                case .config:
                    Section("配置管理") {
                        paramRow("读取配置", params: ["action": "read"])
                        paramRow("验证配置", params: ["action": "validate"])
                    }
                default:
                    EmptyView()
                }
            }
            .navigationTitle(commandType.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func paramRow(_ label: String, params: [String: Any]) -> some View {
        Button {
            onConfirm(params.isEmpty ? nil : params)
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}
