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

    private var latestMetric: SystemMetric? {
        viewModel.metrics.max(by: { $0.metricTime < $1.metricTime }) ?? currentDevice.latestMetric
    }

    var body: some View {
        ZStack {
            AppColors.gradientBg.ignoresSafeArea()

            if viewModel.isLoading && viewModel.device == nil {
                ProgressView().tint(AppColors.primary)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        summaryStrip
                        tabBar
                        workspaceContent
                    }
                    .padding()
                }
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
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private func reloadAll() async {
        await viewModel.load()
        await viewModel.loadMetrics()
        await viewModel.loadSkills()
    }

    private func toggleStatus(to newStatus: Int8) async {
        struct StatusBody: Encodable { let status: Int8 }
        do {
            try await APIClient.shared.requestVoid(.deviceStatus(id: currentDevice.id), body: StatusBody(status: newStatus))
            await viewModel.load()
        } catch {}
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("设备")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(currentDevice.hostname)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textTitle)
                    HStack(spacing: 8) {
                        StatusBadge.deviceStatus(currentDevice.status)
                        pill(text: "心跳 \(currentDevice.lastHeartbeatAt?.relativeString ?? "--")")
                    }
                }
                Spacer()
            }

            HStack(spacing: 8) {
                pill(text: "OpenClaw \(openClawInfo?.overview?.version ?? currentDevice.agentVersion)")
                if let model = openClawInfo?.model, !model.isEmpty {
                    pill(text: model)
                }
                if !agentList.isEmpty {
                    pill(text: "\(agentList.count) Agents")
                }
            }
        }
        .padding(20)
        .cardStyle()
    }

    private var summaryStrip: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(
                title: "设备状态",
                value: currentDevice.deviceStatus == .online ? "在线" : (currentDevice.deviceStatus == .disabled ? "禁用" : "离线"),
                detail: "最近心跳 \(currentDevice.lastHeartbeatAt?.relativeString ?? "--")",
                accent: currentDevice.isOnline ? AppColors.success : AppColors.error
            )
            summaryCard(
                title: "OpenClaw",
                value: openClawInfo?.overview?.version ?? currentDevice.agentVersion,
                detail: openClawInfo?.model ?? "待模型",
                accent: AppColors.primary
            )
            summaryCard(
                title: "Agents",
                value: "\(agentList.count)",
                detail: agentList.isEmpty ? (openClawInfo?.overview?.agentsSummary ?? "待上报") : "\(agentList.filter(isAgentOnline).count) 在线",
                accent: AppColors.cyan
            )
            summaryCard(
                title: "运行时间",
                value: uptimeString(from: currentDevice.registeredAt),
                detail: "注册于 \(formattedDate(currentDevice.registeredAt))",
                accent: AppColors.warning
            )
        }
    }

    private func summaryCard(title: String, value: String, detail: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(accent)
            Text(detail)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    private var tabBar: some View {
        HStack(spacing: 10) {
            ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    .foregroundStyle(selectedTab == tab ? AppColors.primary : AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(selectedTab == tab ? AppColors.primary.opacity(0.12) : Color.white.opacity(0.28))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                            .stroke(selectedTab == tab ? AppColors.primary.opacity(0.25) : AppColors.borderColor, lineWidth: 1)
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
            liveSignalsCard
            metricsChartCard
            systemInfoCard
            openClawOverviewCard

            if let channels = openClawInfo?.channels, !channels.isEmpty {
                channelsCard(channels)
            }

            skillsSection
        }
    }

    private var commandWorkspace: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("控制")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
                CommandPanelView(device: currentDevice)
            }
            .padding(20)
            .cardStyle()

            VStack(alignment: .leading, spacing: 12) {
                Text("检查")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
                checklistRow("1. 先看设备是否持续在线，以及最近心跳是否正常。")
                checklistRow("2. 先跑状态查询 / 健康诊断，再决定是否执行重启或更新。")
                checklistRow("3. Gateway、Sessions、Update 类命令优先在空闲时段执行。")
            }
            .padding(20)
            .cardStyle()

            VStack(alignment: .leading, spacing: 12) {
                Text("上下文")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
                infoRows([
                    ("设备状态", currentDevice.deviceStatus == .online ? "在线" : (currentDevice.deviceStatus == .disabled ? "禁用" : "离线")),
                    ("最近心跳", currentDevice.lastHeartbeatAt?.relativeString ?? "--"),
                    ("Gateway", openClawInfo?.overview?.gateway ?? "—"),
                    ("Node", openClawInfo?.overview?.node ?? "—"),
                    ("Dashboard", openClawInfo?.overview?.dashboard ?? "—"),
                    ("Model", openClawInfo?.model ?? "—"),
                ])
            }
            .padding(20)
            .cardStyle()
        }
    }

    private var agentWorkspace: some View {
        VStack(spacing: 16) {
            if let info = openClawInfo,
               !agentList.isEmpty || info.overview?.agentsSummary != nil {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Agents")
                            .font(.headline)
                            .foregroundStyle(AppColors.textTitle)
                        Spacer()
                        Text(agentList.isEmpty ? (info.overview?.agentsSummary ?? "待上报") : "\(agentList.filter(isAgentOnline).count) 在线 / \(agentList.count) 总数")
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
                                    agentsSummary: info.overview?.agentsSummary,
                                    deviceId: currentDevice.deviceId,
                                    deviceInternalId: currentDevice.id,
                                    initialAgentId: agent.id,
                                    showAgentSelector: false
                                )
                                .navigationTitle(agent.name)
                                .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                agentDirectoryRow(agent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .cardStyle()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Agents")
                        .font(.headline)
                        .foregroundStyle(AppColors.textTitle)
                    emptyHint("无 Agents")
                }
                .padding(20)
                .cardStyle()
            }
        }
    }

    private var liveSignalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("资源")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
                Spacer()
                if latestMetric != nil {
                    pill(text: "实时指标")
                }
            }

            if let metric = latestMetric {
                VStack(spacing: 12) {
                    signalBar(title: "CPU", value: metric.cpuUsage, detail: "\(currentDevice.cpuModel) · \(currentDevice.cpuCores) 核")
                    signalBar(title: "内存", value: metric.memoryUsage, detail: "\(formattedBytes(metric.memoryUsed)) / \(currentDevice.formattedMemory)")
                    signalBar(title: "磁盘", value: metric.diskUsage, detail: "\(formattedBytes(metric.diskUsed)) / \(currentDevice.formattedDisk)")
                }
            } else {
                emptyHint("无指标")
            }
        }
        .padding(20)
        .cardStyle()
    }

    private func signalBar(title: String, value: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                signalPill(value: value)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.35))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(signalColor(for: value))
                        .frame(width: proxy.size.width * min(max(value, 0), 100) / 100)
                }
            }
            .frame(height: 10)

            Text(detail)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
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

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设备信息")
                .font(.headline)
                .foregroundStyle(AppColors.textTitle)

            infoRows([
                ("设备 ID", currentDevice.deviceId),
                ("Node ID", currentDevice.nodeId ?? "—"),
                ("系统版本", currentDevice.osVersion),
                ("Agent 版本", currentDevice.agentVersion),
                ("CPU", currentDevice.cpuModel),
                ("内存", currentDevice.formattedMemory),
                ("磁盘", currentDevice.formattedDisk),
                ("注册时间", formattedDate(currentDevice.registeredAt)),
            ])
        }
        .padding(20)
        .cardStyle()
    }

    private var openClawOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenClaw")
                .font(.headline)
                .foregroundStyle(AppColors.textTitle)

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
                emptyHint("无 OpenClaw 数据")
            }
        }
        .padding(20)
        .cardStyle()
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
            Text("Channels")
                .font(.headline)
                .foregroundStyle(AppColors.textTitle)

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
        .padding(20)
        .cardStyle()
    }

    @ViewBuilder
    private var skillsSection: some View {
        if !viewModel.skills.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Skills")
                        .font(.headline)
                        .foregroundStyle(AppColors.textTitle)
                    Spacer()
                    Text("\(viewModel.skills.count) / \(viewModel.skillTotal)")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                FlowLayout(spacing: 8) {
                    ForEach(viewModel.skills) { skill in
                        skillTag(skill)
                    }
                }
            }
            .padding(20)
            .cardStyle()
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

    private func checklistRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AppColors.primary)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
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

    private func agentDirectoryRow(_ agent: OpenClawAgent) -> some View {
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
                Text(agent.id)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                statusChip(text: online ? "在线" : "离线", color: online ? AppColors.success : AppColors.disabled)
                if let sessions = agent.sessions {
                    statusChip(text: "\(sessions) 会话", color: AppColors.primary)
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

    private func signalPill(value: Double) -> some View {
        let color = signalColor(for: value)
        return Text("\(Int(value.rounded()))%")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
        guard let active = agent.active?.trimmingCharacters(in: .whitespacesAndNewlines),
              !active.isEmpty else { return false }
        let lower = active.lowercased()
        if ["true", "yes", "online", "active", "now"].contains(lower) {
            return true
        }
        guard let age = parseActiveAge(lower) else { return false }
        return age <= 3600
    }

    private func parseActiveAge(_ value: String) -> TimeInterval? {
        let parts = value.split(separator: " ")
        guard let token = parts.first else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let unit = trimmed.last else { return nil }
        let numberStr = trimmed.dropLast()
        guard let num = Double(numberStr) else { return nil }

        switch unit {
        case "s": return num
        case "m": return num * 60
        case "h": return num * 3600
        case "d": return num * 86400
        case "w": return num * 604800
        default: return nil
        }
    }

    private func signalColor(for value: Double) -> Color {
        switch value {
        case 80...: return AppColors.error
        case 60...: return AppColors.warning
        default: return AppColors.success
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func uptimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let days = Int(interval / 86400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }
}
