import SwiftUI
import UIKit

struct CommandListView: View {
    private let topContentSpacing: CGFloat = 8
    private enum StatusFilter: String, CaseIterable, Identifiable {
        case all
        case pending
        case running
        case failed
        case success

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "全部"
            case .pending: return "等待"
            case .running: return "处理中"
            case .failed: return "失败"
            case .success: return "成功"
            }
        }

        func matches(_ command: AgentCommand) -> Bool {
            switch self {
            case .all: return true
            case .pending: return command.commandStatus == .pending
            case .running: return command.commandStatus == .running
            case .failed: return command.commandStatus == .failed || command.commandStatus == .timeout
            case .success: return command.commandStatus == .success
            }
        }
    }

    private enum GroupFilter: String, CaseIterable, Identifiable {
        case all
        case control
        case diagnose
        case manage

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "全部类型"
            case .control: return AgentCommand.CommandGroup.control.label
            case .diagnose: return AgentCommand.CommandGroup.diagnose.label
            case .manage: return AgentCommand.CommandGroup.manage.label
            }
        }

        func matches(_ command: AgentCommand) -> Bool {
            guard self != .all else { return true }
            guard let type = command.commandTypeEnum else { return false }
            switch self {
            case .all: return true
            case .control: return AgentCommand.CommandGroup.control.types.contains(type)
            case .diagnose: return AgentCommand.CommandGroup.diagnose.types.contains(type)
            case .manage: return AgentCommand.CommandGroup.manage.types.contains(type)
            }
        }
    }

    @State private var viewModel = CommandViewModel()
    @State private var selectedCommand: AgentCommand?
    @State private var statusFilter: StatusFilter = .all
    @State private var groupFilter: GroupFilter = .all
    @State private var showCleanupDialog = false
    @State private var pendingDeleteCommand: AgentCommand?
    @State private var infoMessage: String?

    private var filteredCommands: [AgentCommand] {
        viewModel.commands.filter { statusFilter.matches($0) && groupFilter.matches($0) }
    }

    private var deletableFilteredCommands: [AgentCommand] {
        filteredCommands.filter(\.isDeletable)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                if viewModel.isLoading && viewModel.commands.isEmpty {
                    ProgressView().tint(AppColors.primary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            filterBar

                            if filteredCommands.isEmpty {
                                EmptyStateView(
                                    icon: "line.3.horizontal.decrease.circle",
                                    title: "无匹配记录",
                                    subtitle: "切换筛选"
                                )
                                .padding(.top, 24)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(filteredCommands) { command in
                                        Button {
                                            selectedCommand = command
                                        } label: {
                                            CommandRowView(command: command)
                                        }
                                        .buttonStyle(.plain)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            if command.isDeletable {
                                                Button(role: .destructive) {
                                                    pendingDeleteCommand = command
                                                } label: {
                                                    Label("删除", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.pageHorizontalPadding)
                        .padding(.vertical, 16)
                        .padding(.top, topContentSpacing)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable { await viewModel.loadCommands() }
                }
            }
            .navigationTitle("命令")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("删除当前筛选结果", role: .destructive) {
                            if deletableFilteredCommands.isEmpty {
                                infoMessage = "当前筛选没有可删除记录"
                            } else {
                                showCleanupDialog = true
                            }
                        }
                        Button("删除全部失败记录", role: .destructive) {
                            Task { await runCleanup(statuses: [.failed, .timeout]) }
                        }
                        Button("删除全部成功记录", role: .destructive) {
                            Task { await runCleanup(statuses: [.success]) }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(AppColors.error)
                    }
                }
            }
            .sheet(item: $selectedCommand) { command in
                CommandDetailSheet(command: command) {
                    let deleted = await viewModel.deleteCommand(command.id)
                    if deleted {
                        selectedCommand = nil
                        infoMessage = "已删除"
                    } else {
                        infoMessage = viewModel.errorMessage ?? "删除失败"
                    }
                }
            }
            .confirmationDialog("清理记录", isPresented: $showCleanupDialog, titleVisibility: .visible) {
                Button("删除当前筛选结果", role: .destructive) {
                    Task { await runCleanupCurrentFilter() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("仅删除已完成记录，处理中命令会保留。")
            }
            .alert("删除命令记录", isPresented: Binding(
                get: { pendingDeleteCommand != nil },
                set: { if !$0 { pendingDeleteCommand = nil } }
            ), presenting: pendingDeleteCommand) { command in
                Button("删除", role: .destructive) {
                    Task {
                        let deleted = await viewModel.deleteCommand(command.id)
                        infoMessage = deleted ? "已删除" : (viewModel.errorMessage ?? "删除失败")
                    }
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text("删除后无法恢复，原文输出和错误记录会一并删除。")
            }
            .alert("提示", isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )) {
                Button("确定", role: .cancel) { infoMessage = nil }
            } message: {
                Text(infoMessage ?? "")
            }
        }
        .task {
            await viewModel.loadCommands()
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            compactFilterMenu(
                title: "状态",
                value: statusFilter.label
            ) {
                ForEach(StatusFilter.allCases) { filter in
                    Button(filter.label) {
                        statusFilter = filter
                    }
                }
            }

            compactFilterMenu(
                title: "类型",
                value: groupFilter.label
            ) {
                ForEach(GroupFilter.allCases) { filter in
                    Button(filter.label) {
                        groupFilter = filter
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: AppTheme.topModuleMinHeight)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppColors.borderColor, lineWidth: 1)
        )
    }

    private func compactFilterMenu<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(value)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: AppTheme.topModuleMinHeight - 8)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func runCleanupCurrentFilter() async {
        guard !deletableFilteredCommands.isEmpty else {
            infoMessage = "当前筛选没有可删除记录"
            return
        }

        let statuses: [Int8]? = switch statusFilter {
        case .failed: [AgentCommand.Status.failed.rawValue, AgentCommand.Status.timeout.rawValue]
        case .success: [AgentCommand.Status.success.rawValue]
        default: nil
        }

        let commandTypes: [String]? = switch groupFilter {
        case .all: nil
        case .control: AgentCommand.CommandGroup.control.types.map(\.rawValue)
        case .diagnose: AgentCommand.CommandGroup.diagnose.types.map(\.rawValue)
        case .manage: AgentCommand.CommandGroup.manage.types.map(\.rawValue)
        }

        let deleted = await viewModel.cleanupCommands(commandTypes: commandTypes, statuses: statuses)
        if let deleted {
            infoMessage = deleted > 0 ? "已删除 \(deleted) 条" : "无可删除记录"
        } else {
            infoMessage = viewModel.errorMessage ?? "清理失败"
        }
    }

    @MainActor
    private func runCleanup(statuses: [AgentCommand.Status]) async {
        let deleted = await viewModel.cleanupCommands(statuses: statuses.map(\.rawValue))
        if let deleted {
            infoMessage = deleted > 0 ? "已删除 \(deleted) 条" : "无可删除记录"
        } else {
            infoMessage = viewModel.errorMessage ?? "清理失败"
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
                    Text(command.createdAt.relativeString)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)

                    if command.isEncrypted {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColors.success)
                    }
                }

                if !command.errorMessage.isEmpty {
                    Text(command.errorMessage)
                        .font(.caption2)
                        .foregroundStyle(AppColors.error)
                        .lineLimit(1)
                } else if !command.result.isEmpty {
                    Text(command.result)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .cardStyle()
    }
}

struct CommandDetailSheet: View {
    enum RawContent: Identifiable {
        case output(String)
        case error(String)

        var id: String {
            switch self {
            case .output: return "output"
            case .error: return "error"
            }
        }

        var title: String {
            switch self {
            case .output: return "原文输出"
            case .error: return "原文错误"
            }
        }

        var text: String {
            switch self {
            case .output(let text), .error(let text): return text
            }
        }

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    let command: AgentCommand
    let onDelete: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rawContent: RawContent?
    @State private var showDeleteAlert = false

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
                            detailRow("创建时间", command.createdAt.fullString)
                            if let executed = command.executedAt {
                                detailRow("执行时间", executed.fullString)
                            }
                        }
                        .padding()
                        .cardStyle()

                        if !command.result.isEmpty {
                            rawPreviewCard(
                                title: "原文输出",
                                text: command.result,
                                isError: false,
                                action: { rawContent = .output(command.result) }
                            )
                        }

                        if !command.errorMessage.isEmpty {
                            rawPreviewCard(
                                title: "原文错误",
                                text: command.errorMessage,
                                isError: true,
                                action: { rawContent = .error(command.errorMessage) }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("命令详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if command.isDeletable {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(AppColors.primary)
                    }
                }
            }
            .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .sheet(item: $rawContent) { content in
            RawTextSheet(content: content)
        }
        .alert("删除命令记录", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，原文输出和错误记录会一并删除。")
        }
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


    private func rawPreviewCard(
        title: String,
        text: String,
        isError: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isError ? AppColors.error : AppColors.textTitle)
                Spacer()
                Button("查看全文", action: action)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
            }

            Text(rawPreview(text))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isError ? AppColors.error.opacity(0.85) : AppColors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    Group {
                        if isError {
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                .fill(AppColors.error.opacity(0.08))
                        } else {
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                .fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .stroke(isError ? AppColors.error.opacity(0.18) : AppColors.borderColor, lineWidth: 1)
                )

            HStack {
                Text(rawMeta(text))
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Button("复制") {
                    UIPasteboard.general.string = text
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding()
        .cardStyle()
    }

    private func rawPreview(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.count <= 600 {
            return normalized
        }
        return String(normalized.prefix(600)) + "\n..."
    }

    private func rawMeta(_ text: String) -> String {
        let lineCount = max(text.components(separatedBy: .newlines).count, 1)
        return "\(lineCount) 行 · \(text.count) 字符"
    }
}

private extension AgentCommand {
    var isDeletable: Bool {
        commandStatus == .success || commandStatus == .failed || commandStatus == .timeout
    }
}

private struct RawTextSheet: View {
    let content: CommandDetailSheet.RawContent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                ScrollView([.vertical, .horizontal]) {
                    Text(content.text)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(content.isError ? AppColors.error.opacity(0.85) : AppColors.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .navigationTitle(content.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("复制") {
                        UIPasteboard.general.string = content.text
                    }
                    .foregroundStyle(AppColors.primary)
                }
            }
        }
        .presentationDetents([.large])
    }
}
