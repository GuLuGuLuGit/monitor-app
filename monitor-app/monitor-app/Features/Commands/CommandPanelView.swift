import SwiftUI

struct CommandPanelView: View {
    let device: Device
    @State private var viewModel = CommandViewModel()
    @State private var showConfirm = false
    @State private var pendingCommand: AgentCommand.CommandType?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷操作")
                .font(.headline)
                .foregroundStyle(AppColors.textTitle)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 10) {
                ForEach(AgentCommand.CommandType.allCases, id: \.rawValue) { cmdType in
                    commandButton(cmdType)
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
            Button("取消", role: .cancel) { pendingCommand = nil }
            Button("确认") {
                guard let cmd = pendingCommand else { return }
                Task {
                    await viewModel.sendCommand(
                        deviceId: device.deviceId,
                        deviceInternalId: device.id,
                        commandType: cmd
                    )
                }
                pendingCommand = nil
            }
        } message: {
            if let cmd = pendingCommand {
                Text("确定要对 \(device.hostname) 执行「\(cmd.label)」操作吗？")
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
            pendingCommand = type
            showConfirm = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(buttonColor(type))

                Text(type.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .cardStyle()
        }
        .disabled(viewModel.isSending)
    }

    private func buttonColor(_ type: AgentCommand.CommandType) -> Color {
        switch type {
        case .start: AppColors.success
        case .stop: AppColors.error
        case .restart: AppColors.warning
        case .status: AppColors.primary
        case .config: AppColors.cyan
        }
    }
}
