import SwiftUI

struct CommandPanelView: View {
    let device: Device
    @State private var viewModel = CommandViewModel()
    @State private var showConfirm = false
    @State private var pendingCommand: AgentCommand.CommandType?
    @State private var pendingParams: [String: Any]?
    @State private var paramSheetType: AgentCommand.CommandType?

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(AgentCommand.CommandGroup.allCases, id: \.rawValue) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(group.label)
                                .font(.headline)
                                .foregroundStyle(AppColors.textTitle)
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

                    if group != AgentCommand.CommandGroup.allCases.last {
                        Divider()
                            .background(AppColors.borderColor)
                            .padding(.top, 4)
                    }
                }

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.errorMessage = nil
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.isSending {
                LoadingOverlay(message: "发送中")
                    .frame(maxWidth: .infinity, minHeight: 420, maxHeight: .infinity, alignment: .center)
                    .zIndex(1)
            }
        }
        .alert("确认执行", isPresented: $showConfirm) {
            Button("取消", role: .cancel) { pendingCommand = nil; pendingParams = nil }
            Button("确认") {
                guard let cmd = pendingCommand else { return }
                Task {
                    let success = await viewModel.sendCommand(
                        deviceId: device.deviceId,
                        deviceInternalId: device.id,
                        commandType: cmd,
                        params: pendingParams
                    )
                    if success {
                        ToastManager.shared.show(.success, message: "\(cmd.label)已发送", duration: 2)
                    } else {
                        ToastManager.shared.show(
                            .error,
                            message: viewModel.errorMessage ?? "\(cmd.label)发送失败",
                            duration: 4
                        )
                    }
                }
                pendingCommand = nil
                pendingParams = nil
            }
        } message: {
            if let cmd = pendingCommand {
                Text("确定要对 \(device.hostname) 执行「\(cmd.label)」操作吗？")
            }
        }
        .sheet(item: $paramSheetType) { cmdType in
            ParamSheetView(commandType: cmdType) { params in
                paramSheetType = nil
                pendingCommand = cmdType
                pendingParams = params
                showConfirm = true
            }
            .presentationDetents([.medium])
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            guard let newValue, !newValue.isEmpty, !viewModel.isSending else { return }
            ToastManager.shared.show(.error, message: newValue, duration: 4)
        }
    }

    private func commandButton(_ type: AgentCommand.CommandType) -> some View {
        Button {
            if type.needsParams {
                paramSheetType = type
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
        case .start: return "启动服务"
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

extension AgentCommand.CommandType: Identifiable {
    var id: String { rawValue }
}

private struct ParamSheetView: View {
    let commandType: AgentCommand.CommandType
    let onConfirm: ([String: Any]?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(commandType.label)
                        .font(.headline)
                        .foregroundStyle(AppColors.textTitle)
                    Text(sheetSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(sheetOptions.enumerated()), id: \.offset) { index, option in
                    paramRow(option.title, params: option.params)
                    if index < sheetOptions.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .background(Color.white.opacity(0.32))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppColors.borderColor, lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppColors.bgPrimary, AppColors.bgSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private var sheetSubtitle: String {
        switch commandType {
        case .gateway: "选择要执行的 Gateway 操作"
        case .logs: "选择日志查看范围"
        case .update: "选择更新方式"
        case .sessions: "选择会话管理操作"
        case .security: "选择安全审计级别"
        case .config: "选择配置相关操作"
        default: "选择一个操作"
        }
    }

    private var sheetOptions: [(title: String, params: [String: Any])] {
        switch commandType {
        case .gateway:
            return [
                ("查看状态", ["action": "status"]),
                ("健康检查", ["action": "health"]),
                ("重启 Gateway", ["action": "restart"]),
            ]
        case .logs:
            return [
                ("最近 50 行", ["lines": 50]),
                ("最近 200 行", ["lines": 200]),
                ("最近 500 行", ["lines": 500]),
            ]
        case .update:
            return [
                ("检查更新", ["action": "check"]),
                ("执行更新", ["action": "apply"]),
                ("更新到 Beta", ["action": "apply", "channel": "beta"]),
            ]
        case .sessions:
            return [
                ("查看会话列表", ["action": "list"]),
                ("清理预览 (dry-run)", ["action": "cleanup", "dry_run": true]),
                ("执行清理", ["action": "cleanup"]),
            ]
        case .security:
            return [
                ("标准审计", [:]),
                ("深度审计", ["deep": true]),
            ]
        case .config:
            return [
                ("读取配置", ["action": "read"]),
                ("验证配置", ["action": "validate"]),
            ]
        default:
            return []
        }
    }

    private func paramRow(_ label: String, params: [String: Any]) -> some View {
        Button {
            onConfirm(params.isEmpty ? nil : params)
        } label: {
            HStack {
                Image(systemName: commandType.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)
                Text(label)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
