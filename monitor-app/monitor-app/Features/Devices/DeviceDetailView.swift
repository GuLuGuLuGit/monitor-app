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
            AppColors.bgPrimary.ignoresSafeArea()

            if viewModel.isLoading && viewModel.device == nil {
                ProgressView().tint(AppColors.primary)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        CommandPanelView(device: currentDevice)
                        systemInfoCard
                        metricsChartCard
                        openClawSection
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.load()
                    await viewModel.loadMetrics()
                }
            }
        }
        .navigationTitle(currentDevice.hostname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
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

                if let agents = info.agents, !agents.isEmpty {
                    agentsCard(agents)
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

    private func agentsCard(_ agents: [OpenClawAgent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agents (\(agents.count))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textTitle)

            ForEach(agents) { agent in
                HStack {
                    Circle()
                        .fill(agent.active == "true" ? AppColors.success : AppColors.textSecondary)
                        .frame(width: 6, height: 6)
                    Text(agent.name)
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    if let sessions = agent.sessions {
                        Text("\(sessions) sessions")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
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
