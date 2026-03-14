import SwiftUI
import Charts

struct DeviceDetailView: View {
    let device: Device
    @State private var viewModel: DeviceDetailViewModel
    @State private var showDeleteConfirm = false
    @State private var showStatusAction = false
    @Environment(\.dismiss) private var dismiss

    init(device: Device) {
        self.device = device
        self._viewModel = State(initialValue: DeviceDetailViewModel(deviceId: device.id))
    }

    private var currentDevice: Device {
        viewModel.device ?? device
    }

    var body: some View {
        ZStack {
            AppColors.gradientBg.ignoresSafeArea()

            if viewModel.isLoading && viewModel.device == nil {
                ProgressView().tint(AppColors.primary)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        CommandPanelView(device: currentDevice)
                        systemInfoCard
                        metricsChartCard

                        agentMessageSection

                        skillsSection
                        openClawSection
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.load()
                    await viewModel.ensureAgentsLoaded(force: true)
                    await viewModel.loadMetrics()
                    await viewModel.loadSkills()
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
            await viewModel.load()
            await viewModel.loadMetrics()
            await viewModel.loadSkills()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private func toggleStatus(to newStatus: Int8) async {
        struct StatusBody: Encodable { let status: Int8 }
        do {
            try await APIClient.shared.requestVoid(.deviceStatus(id: currentDevice.id), body: StatusBody(status: newStatus))
            await viewModel.load()
        } catch {}
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColors.primary)
                    .shadow(color: AppColors.primary.opacity(0.2), radius: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentDevice.hostname)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textTitle)

                    StatusBadge.deviceStatus(currentDevice.status)
                }

                Spacer()
            }

            if let heartbeat = currentDevice.lastHeartbeatAt {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("最近心跳: \(heartbeat.relativeString)")
                        .font(.caption)
                }
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .cardStyle()
    }

    // MARK: - System Info Card

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统信息")
                .font(.headline)
                .foregroundStyle(AppColors.textTitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                infoRow(icon: "desktopcomputer", label: "设备 ID", value: String(currentDevice.deviceId.prefix(12)) + "...")
                infoRow(icon: "cpu", label: "CPU", value: "\(currentDevice.cpuModel)")
                infoRow(icon: "cpu.fill", label: "核心数", value: "\(currentDevice.cpuCores)")
                infoRow(icon: "memorychip", label: "内存", value: currentDevice.formattedMemory)
                infoRow(icon: "internaldrive", label: "磁盘", value: currentDevice.formattedDisk)
                infoRow(icon: "app.badge", label: "Agent", value: currentDevice.agentVersion)
            }
        }
        .padding()
        .cardStyle()
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColors.primary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Metrics Chart

    @ViewBuilder
    private var metricsChartCard: some View {
        if !viewModel.metrics.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("系统指标 (24h)")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)

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
                .chartLegend(position: .top, alignment: .leading) {
                    HStack(spacing: 16) {
                        legendItem(color: AppColors.primary, label: "CPU")
                        legendItem(color: AppColors.cyan, label: "内存")
                        legendItem(color: AppColors.warning, label: "磁盘")
                    }
                }
                .frame(height: 200)
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.clear)
                }
            }
            .padding()
            .cardStyle()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2).foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Skills Section

    @ViewBuilder
    private var agentMessageSection: some View {
        if let info = viewModel.openClawInfo,
           (info.agents ?? []).isEmpty == false || info.overview?.agentsSummary != nil || viewModel.isLoadingAgents {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundStyle(AppColors.primary)
                    Text("Agent 消息")
                        .font(.headline)
                        .foregroundStyle(AppColors.textTitle)
                    Spacer()
                    if viewModel.isLoadingAgents {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(AppColors.primary)
                    } else if let agents = info.agents, !agents.isEmpty {
                        Text("\(agents.count)")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    } else if let summary = info.overview?.agentsSummary {
                        Text(summary)
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                if let agents = info.agents, !agents.isEmpty {
                    ForEach(agents) { agent in
                        NavigationLink {
                            AgentChatView(
                                agents: agents,
                                agentsSummary: info.overview?.agentsSummary,
                                deviceId: currentDevice.deviceId,
                                deviceInternalId: currentDevice.id,
                                initialAgentId: agent.id,
                                showAgentSelector: false
                            )
                            .navigationTitle(agent.name)
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            agentRow(agent)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(viewModel.isLoadingAgents ? "正在获取当前设备的 Agent 列表" : "暂未获取到 Agent 列表")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding()
            .cardStyle()
        }
    }

    @ViewBuilder
    private var skillsSection: some View {
        if !viewModel.skills.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(AppColors.warning)
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
            .padding()
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
            (Color(hex: "8b5cf6").opacity(0.15), Color(hex: "8b5cf6")),
            (Color(hex: "f59e0b").opacity(0.15), Color(hex: "d97706")),
            (Color(hex: "22d3ee").opacity(0.15), Color(hex: "0891b2")),
            (Color(hex: "ec4899").opacity(0.15), Color(hex: "db2777")),
            (Color(hex: "f87171").opacity(0.15), Color(hex: "dc2626")),
            (Color(hex: "4ade80").opacity(0.15), Color(hex: "16a34a")),
        ]
        var h = 0
        for c in name.unicodeScalars { h = ((h &<< 5) &- h) &+ Int(c.value) }
        let idx = abs(h) % palettes.count
        return (palettes[idx].0, palettes[idx].1)
    }

    // MARK: - OpenClaw Section

    @ViewBuilder
    private var openClawSection: some View {
        if let info = viewModel.openClawInfo {
            VStack(alignment: .leading, spacing: 12) {
                Text("OpenClaw 信息")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)

                if let overview = info.overview {
                    overviewCard(overview)
                }

                if let channels = info.channels, !channels.isEmpty {
                    channelsCard(channels)
                }
            }
        }
    }

    private func overviewCard(_ overview: OpenClawOverview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("概览")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textTitle)

            Group {
                if let v = overview.version { overviewRow("版本", v) }
                if let v = overview.node { overviewRow("节点", v) }
                if let v = overview.gateway { overviewRow("网关", v) }
                if let v = overview.tailscale { overviewRow("Tailscale", v) }
                if let v = overview.agentsSummary { overviewRow("Agents", v) }
            }
        }
        .padding()
        .cardStyle()
    }

    private func overviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
            Spacer()
        }
    }

    private func agentRow(_ agent: OpenClawAgent) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isAgentOnline(agent) ? AppColors.success : AppColors.disabled)
                .frame(width: 8, height: 8)

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

            if let sessions = agent.sessions {
                Text("\(sessions) sessions")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func isAgentOnline(_ agent: OpenClawAgent) -> Bool {
        guard let active = agent.active?.trimmingCharacters(in: .whitespacesAndNewlines),
              !active.isEmpty else { return false }
        let lower = active.lowercased()
        if ["true", "yes", "online", "active", "now"].contains(lower) {
            return true
        }
        guard let token = lower.split(separator: " ").first,
              let unit = token.last,
              let num = Double(token.dropLast()) else {
            return false
        }

        let age: Double
        switch unit {
        case "s": age = num
        case "m": age = num * 60
        case "h": age = num * 3600
        case "d": age = num * 86400
        case "w": age = num * 604800
        default: return false
        }
        return age <= 3600
    }

    private func channelsCard(_ channels: [OpenClawChannel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("渠道 (\(channels.count))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textTitle)

            ForEach(channels) { channel in
                HStack {
                    Circle()
                        .fill(channel.enabled ? AppColors.success : AppColors.disabled)
                        .frame(width: 6, height: 6)
                    Text(channel.type)
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    if let state = channel.state {
                        Text(state)
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }
}
