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
            ForEach(AgentCommand.CommandGroup.allCases, id: \.rawValue) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textSecondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 10) {
                        ForEach(group.types, id: \.rawValue) { cmdType in
                            commandButton(cmdType)
                        }
                    }
                }
            }

            if let msg = viewModel.successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(AppColors.success)
                }
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
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundStyle(buttonColor(type))

                Text(type.label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .cardStyle()
        }
        .disabled(viewModel.isSending)
    }

    private func buttonColor(_ type: AgentCommand.CommandType) -> Color {
        switch type {
        case .start: AppColors.success
        case .stop: AppColors.error
        case .restart, .gateway: AppColors.warning
        case .status, .doctor, .probe, .logs: AppColors.primary
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
