import SwiftUI

struct CommandListView: View {
    @State private var viewModel = CommandViewModel()
    @State private var selectedCommand: AgentCommand?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                if viewModel.isLoading && viewModel.commands.isEmpty {
                    ProgressView().tint(AppColors.primary)
                } else if viewModel.commands.isEmpty {
                    EmptyStateView(icon: "terminal.fill", title: "暂无命令记录")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.commands) { command in
                                Button {
                                    selectedCommand = command
                                } label: {
                                    CommandRowView(command: command)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .refreshable { await viewModel.loadCommands() }
                }
            }
            .navigationTitle("命令")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedCommand) { command in
                CommandDetailSheet(command: command)
            }
        }
        .task {
            await viewModel.loadCommands()
        }
    }
}

struct CommandRowView: View {
    let command: AgentCommand

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.commandTypeEnum?.icon ?? "terminal")
                .font(.title3)
                .foregroundStyle(AppColors.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(command.commandTypeEnum?.label ?? command.commandType)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    StatusBadge.commandStatus(command.status)
                }

                HStack(spacing: 8) {
                    Text(String(command.deviceId.prefix(8)))
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(AppColors.textSecondary)

                    Text(command.createdAt.relativeString)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)

                    if command.isEncrypted {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColors.success)
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
    }
}

struct CommandDetailSheet: View {
    let command: AgentCommand
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(command.commandTypeEnum?.label ?? command.commandType)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.textTitle)
                            Spacer()
                            StatusBadge.commandStatus(command.status)
                        }

                        VStack(spacing: 8) {
                            detailRow("设备", String(command.deviceId.prefix(12)) + "...")
                            detailRow("创建者", command.createdBy)
                            detailRow("创建时间", command.createdAt.fullString)
                            if let executed = command.executedAt {
                                detailRow("执行时间", executed.fullString)
                            }
                            detailRow("加密", command.isEncrypted ? "是" : "否")
                        }
                        .padding()
                        .cardStyle()

                        if !command.result.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("执行结果")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.textTitle)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    Text(command.result)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .textSelection(.enabled)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                            }
                        }

                        if !command.errorMessage.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("错误信息")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.error)

                                Text(command.errorMessage)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(AppColors.error.opacity(0.8))
                                    .textSelection(.enabled)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppColors.error.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("命令详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
        }
    }
}
