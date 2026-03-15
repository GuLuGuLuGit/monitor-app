import SwiftUI
import Charts

struct DeviceDetailView: View {
    enum WorkspaceTab: String, CaseIterable {
        case status = "状态"
        case commands = "命令"
        case agents = "Agent"

        var icon: String {
            switch self {
            case .status: return "waveform.path.ecg"
            case .commands: return "terminal"
            case .agents: return "bubble.left.and.bubble.right"
            }
        }
    }

    let device: Device
    @State private var viewModel: DeviceDetailViewModel
    @State private var showDeleteConfirm = false
    @State private var selectedTab: WorkspaceTab = .status
    @Environment(\.dismiss) private var dismiss

    init(device: Device) {
        self.device = device
        self._viewModel = State(initialValue: DeviceDetailViewModel(deviceId: device.id))
    }

    private var currentDevice: Device {
        viewModel.device ?? device
    }

    private var openClawInfo: OpenClawInfo? {
        viewModel.openClawInfo
    }

    private var agentList: [OpenClawAgent] {
        openClawInfo?.agents ?? []
    }

    private var onlineAgentCount: Int {
        agentList.filter(isAgentOnline).count
    }

    private var latestMetric: SystemMetric? {
        viewModel.metrics.last ?? currentDevice.latestMetric
    }

    var body: some View {
        ZStack {
            AppColors.gradientBg.ignoresSafeArea()

            if viewModel.isLoading && viewModel.device == nil {
                ProgressView().tint(AppColors.primary)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        tabBar
                        workspaceContent
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await reloadAll()
                }
            }
        }
        .navigationTitle(currentDevice.hostname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if currentDevice.status == -1 {
                        Button { Task { await toggleStatus(to: 1) } } label: {
                            Label("启用", systemImage: "checkmark.circle")
                        }
                    } else {
                        Button { Task { await toggleStatus(to: -1) } } label: {
                            Label("禁用", systemImage: "minus.circle")
                        }
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    let vm = DeviceListViewModel()
                    if await vm.deleteDevice(currentDevice) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("确定要删除设备 \(currentDevice.hostname) 吗？此操作不可撤销。")
        }
        .task {
            await reloadAll()
            viewModel.startAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: AgentUnreadStore.didChangeNotification)) { _ in
            Task { await viewModel.load() }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private func reloadAll() async {
        await viewModel.load()
        await viewModel.loadMetrics()
        await viewModel.loadSkills()
        await viewModel.loadRecentAgentActivity()
    }

    private func toggleStatus(to newStatus: Int8) async {
        struct StatusBody: Encodable { let status: Int8 }
        do {
            try await APIClient.shared.requestVoid(.deviceStatus(id: currentDevice.id), body: StatusBody(status: newStatus))
            await viewModel.load()
        } catch {}
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedTab == tab ? AppColors.primary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? AppColors.primary.opacity(0.1) : Color.white.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedTab == tab ? AppColors.primary.opacity(0.18) : AppColors.borderColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var workspaceContent: some View {
        switch selectedTab {
        case .status:
            statusWorkspace
        case .commands:
            commandWorkspace
        case .agents:
            agentWorkspace
        }
    }

    private var statusWorkspace: some View {
        VStack(spacing: 16) {
            metricsChartCard
            skillsCard

            technicalDetails
        }
    }

    private var commandWorkspace: some View {
        VStack(spacing: 16) {
            CommandPanelView(device: currentDevice)
        }
    }

    private var agentWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agents")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
                Spacer()
                Text(agentList.isEmpty ? (openClawInfo?.overview?.agentsSummary ?? "待上报") : "\(onlineAgentCount) 在线 / \(agentList.count) 总数")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if agentList.isEmpty {
                emptyHint("无 Agents")
            } else {
                ForEach(agentList) { agent in
                    NavigationLink {
                        AgentChatView(
                            agents: agentList,
                            agentsSummary: openClawInfo?.overview?.agentsSummary,
                            deviceId: currentDevice.deviceId,
                            deviceInternalId: currentDevice.id,
                            initialAgentId: agent.id,
                            showAgentSelector: false
                        )
                        .navigationTitle(agent.name)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        agentDirectoryRow(agent, unreadCount: viewModel.unreadCount(for: agent.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var metricsChartCard: some View {
        if !viewModel.metrics.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("趋势")
                        .font(.headline)
                        .foregroundStyle(AppColors.textTitle)
                    Spacer()
                    Text("最近 24 小时")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                HStack(spacing: 12) {
                    legendChip(title: "CPU", color: AppColors.primary)
                    legendChip(title: "内存", color: AppColors.cyan)
                    legendChip(title: "磁盘", color: AppColors.warning)
                }

                Chart {
                    ForEach(viewModel.metrics) { metric in
                        LineMark(
                            x: .value("时间", metric.metricTime),
                            y: .value("CPU", metric.cpuUsage),
                            series: .value("类型", "CPU")
                        )
                        .foregroundStyle(AppColors.primary)

                        LineMark(
                            x: .value("时间", metric.metricTime),
                            y: .value("内存", metric.memoryUsage),
                            series: .value("类型", "内存")
                        )
                        .foregroundStyle(AppColors.cyan)

                        LineMark(
                            x: .value("时间", metric.metricTime),
                            y: .value("磁盘", metric.diskUsage),
                            series: .value("类型", "磁盘")
                        )
                        .foregroundStyle(AppColors.warning)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(AppColors.borderColor)
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)%")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(AppColors.borderColor)
                        AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .abbreviated)))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .frame(height: 220)
            }
            .padding(20)
            .cardStyle()
        }
    }

    @ViewBuilder
    private var technicalDetails: some View {
        if shouldShowTechnicalDetails {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    DisclosureGroup("设备信息") {
                        systemInfoCard
                            .padding(.top, 10)
                    }

                    DisclosureGroup("灵控台") {
                        openClawOverviewCard
                            .padding(.top, 10)
                    }

                    if let channels = openClawInfo?.channels, !channels.isEmpty {
                        DisclosureGroup("Channels") {
                            channelsCard(channels)
                                .padding(.top, 10)
                        }
                    }

                    if openClawInfo?.diagnosis != nil {
                        DisclosureGroup("诊断") {
                            diagnosisCard
                                .padding(.top, 10)
                        }
                    }

                }
                .padding(.top, 12)
            } label: {
                HStack {
                    Text("高级信息")
                        .font(.headline)
                        .foregroundStyle(AppColors.textTitle)
                    Spacer()
                    Text("排障时查看")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(20)
            .cardStyle()
        }
    }

    private var shouldShowTechnicalDetails: Bool {
        openClawInfo != nil
    }

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoRows([
                ("设备 ID", currentDevice.deviceId),
                ("Node ID", currentDevice.nodeId ?? "—"),
                ("系统版本", currentDevice.osVersion),
                ("Agent 版本", currentDevice.agentVersion),
                ("CPU", currentDevice.formattedCPU),
                ("内存", currentDevice.formattedMemory(using: latestMetric)),
                ("磁盘", currentDevice.formattedDisk(using: latestMetric)),
                ("注册时间", formattedDate(currentDevice.registeredAt)),
            ])
        }
    }

    private var openClawOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let overview = openClawInfo?.overview {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewStatusTile(title: "Gateway", value: overview.gateway ?? "—")
                    overviewStatusTile(title: "Node", value: overview.node ?? "—")
                    overviewStatusTile(title: "Dashboard", value: overview.dashboard ?? "—")
                    overviewStatusTile(title: "Update", value: overview.update ?? "—")
                }

                infoRows([
                    ("Version", overview.version ?? "—"),
                    ("Model", openClawInfo?.model ?? "—"),
                    ("Config", overview.config ?? "—"),
                    ("Channel", overview.channel ?? "—"),
                    ("Agents", overview.agentsSummary ?? "—"),
                ])
            } else {
                emptyHint("无灵控台数据")
            }
        }
    }

    private var diagnosisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let diagnosis = openClawInfo?.diagnosis {
                infoRows([
                    ("可用技能", "\(diagnosis.skillsEligible ?? 0)"),
                    ("缺失技能", "\(diagnosis.skillsMissing ?? 0)"),
                    ("通路问题", diagnosis.channelIssues ?? "—"),
                ])
            } else {
                emptyHint("无诊断数据")
            }
        }
    }

    private func infoRows(_ rows: [(String, String)]) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 76, alignment: .leading)
                    Text(row.1)
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 10)
                if index < rows.count - 1 {
                    Divider().background(AppColors.borderColor)
                }
            }
        }
    }

    private func overviewStatusTile(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textSecondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
            }
            Spacer()
            stateChip(for: value)
        }
        .padding(14)
        .background(Color.white.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                .stroke(AppColors.borderColor, lineWidth: 1)
        )
    }

    private func channelsCard(_ channels: [OpenClawChannel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(channels) { channel in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(channel.enabled ? AppColors.success : AppColors.disabled)
                            .frame(width: 8, height: 8)
                        Text(channel.type)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text(channel.enabled ? "已启用" : "未启用")
                            .font(.caption2)
                            .foregroundStyle(channel.enabled ? AppColors.success : AppColors.textSecondary)
                    }
                    if let state = channel.state, !state.isEmpty {
                        Text(state)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    if let detail = channel.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.white.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            }
        }
    }

    @ViewBuilder
    private var skillsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skills")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
                Spacer()
                Text(viewModel.skills.isEmpty ? "无 Skills" : "\(viewModel.skills.count) / \(viewModel.skillTotal)")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if viewModel.skills.isEmpty {
                emptyHint("无 Skills")
            } else {
                skillsSection
            }
        }
        .padding(20)
        .cardStyle()
    }

    @ViewBuilder
    private var skillsSection: some View {
        if !viewModel.skills.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.skills) { skill in
                        skillTag(skill)
                    }
                }
            }
        }
    }

    private func skillTag(_ skill: SkillItem) -> some View {
        let colors = skillPalette(for: skill.skillName)
        return HStack(spacing: 4) {
            Text(skill.skillName)
                .font(.caption2)
                .fontWeight(.medium)
            if let ver = skill.skillVersion, !ver.isEmpty {
                Text(ver)
                    .font(.system(size: 9))
                    .opacity(0.7)
            }
        }
        .foregroundStyle(colors.fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(colors.bg)
        .clipShape(Capsule())
    }

    private func skillPalette(for name: String) -> (bg: Color, fg: Color) {
        let palettes: [(Color, Color)] = [
            (Color(hex: "5b8def").opacity(0.15), Color(hex: "5b8def")),
            (Color(hex: "00e676").opacity(0.15), Color(hex: "00c853")),
            (Color(hex: "0ea5e9").opacity(0.15), Color(hex: "0284c7")),
            (Color(hex: "f59e0b").opacity(0.15), Color(hex: "d97706")),
            (Color(hex: "ec4899").opacity(0.15), Color(hex: "db2777")),
            (Color(hex: "8b5cf6").opacity(0.15), Color(hex: "8b5cf6")),
        ]
        var h = 0
        for c in name.unicodeScalars { h = ((h &<< 5) &- h) &+ Int(c.value) }
        let idx = abs(h) % palettes.count
        return (palettes[idx].0, palettes[idx].1)
    }

    private func legendChip(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.22))
        .clipShape(Capsule())
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }

    private func agentDirectoryRow(_ agent: OpenClawAgent, unreadCount: Int) -> some View {
        let online = isAgentOnline(agent)
        return HStack(spacing: 12) {
            Circle()
                .fill(online ? AppColors.success : AppColors.disabled)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text(agent.sessionModel ?? agent.id)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                if let tokens = agent.sessionTokens, !tokens.isEmpty {
                    Text(tokens)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                statusChip(text: online ? "在线" : "离线", color: online ? AppColors.success : AppColors.disabled)
                if let sessions = agent.sessions {
                    statusChip(text: "\(sessions) 会话", color: AppColors.primary)
                }
                if unreadCount > 0 {
                    statusChip(text: "未读 \(unreadCount)", color: AppColors.error)
                }
                if let active = agent.active, !active.isEmpty {
                    Text("最近活跃 \(active)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
        .contentShape(Rectangle())
    }

    private func pill(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.28))
            .clipShape(Capsule())
    }

    private func statusChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func stateChip(for value: String) -> some View {
        let lower = value.lowercased()
        let color: Color
        if lower.contains("ok") || lower.contains("running") || lower.contains("normal") || lower.contains("enabled") || lower.contains("active") || lower.contains("healthy") {
            color = AppColors.success
        } else if lower.contains("pending") || lower.contains("updating") || lower.contains("warning") || lower.contains("partial") {
            color = AppColors.warning
        } else if lower == "—" || lower.contains("unknown") {
            color = AppColors.disabled
        } else {
            color = AppColors.primary
        }

        return Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .shadow(color: color.opacity(0.35), radius: 4)
    }

    private func isAgentOnline(_ agent: OpenClawAgent) -> Bool {
        agent.isLikelyOnline(recentActivityAt: viewModel.recentAgentActivity[agent.id])
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }
}
