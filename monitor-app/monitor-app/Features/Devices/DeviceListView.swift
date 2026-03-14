import SwiftUI

struct DeviceListView: View {
    @State private var viewModel = DeviceListViewModel()
    @State private var showPairing = false
    @State private var selectedDevice: Device?
    @State private var activeLane: WorkLane?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private enum DeviceFilter {
        case all
        case online
        case offline
        case disabled

        var statusValue: Int8? {
            switch self {
            case .all: return nil
            case .online: return 1
            case .offline: return 0
            case .disabled: return -1
            }
        }

        var title: String {
            switch self {
            case .all: return "全部"
            case .online: return "在线"
            case .offline: return "离线"
            case .disabled: return "禁用"
            }
        }
    }

    private enum WorkLane: CaseIterable {
        case alerts
        case unread
        case offline

        var title: String {
            switch self {
            case .alerts: return "告警"
            case .unread: return "未读"
            case .offline: return "离线"
            }
        }

        var icon: String {
            switch self {
            case .alerts: return "exclamationmark.shield"
            case .unread: return "message.badge"
            case .offline: return "wifi.slash"
            }
        }
    }

    private var totalCount: Int { viewModel.devices.count }
    private var onlineCount: Int { viewModel.devices.filter { $0.status == 1 }.count }
    private var offlineCount: Int { viewModel.devices.filter { $0.status == 0 }.count }
    private var disabledCount: Int { viewModel.devices.filter { $0.status == -1 }.count }
    private var searchMatchedDevices: [Device] {
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.devices }
        return viewModel.devices.filter {
            $0.hostname.localizedCaseInsensitiveContains(query) ||
            $0.deviceId.localizedCaseInsensitiveContains(query) ||
            ($0.nodeId?.localizedCaseInsensitiveContains(query) ?? false) ||
            $0.osVersion.localizedCaseInsensitiveContains(query)
        }
    }
    private var scopedDevices: [Device] {
        var devices = searchMatchedDevices
        if let filter = viewModel.statusFilter {
            devices = devices.filter { $0.status == filter }
        }
        if let lane = activeLane {
            devices = devices.filter { matchesLane($0, lane: lane) }
        }
        return devices
    }
    private var attentionDevices: [Device] { prioritizedDevices(from: scopedDevices) }
    private var regularDevices: [Device] {
        let attentionIds = Set(attentionDevices.map(\.id))
        return scopedDevices.filter { !attentionIds.contains($0.id) }
    }
    private var alertCount: Int { prioritizedDevices(from: searchMatchedDevices).count }
    private var unreadCount: Int { searchMatchedDevices.filter { viewModel.unreadCount(for: $0.deviceId) > 0 }.count }
    private var offlineLaneCount: Int { searchMatchedDevices.filter { $0.status != 1 }.count }

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            await viewModel.load()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()
                sidebarWorkspace
            }
            .navigationTitle("设备")
            .searchable(text: $viewModel.searchText, prompt: "搜索设备...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { pairingButton }
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .sheet(isPresented: $showPairing) { PairingView() }
        } detail: {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()
                if let device = selectedDevice {
                    DeviceDetailView(device: device)
                } else {
                    EmptyStateView(icon: "sidebar.left", title: "选择设备", subtitle: "从左侧选择设备")
                }
            }
        }
    }

    private var sidebarWorkspace: some View {
        ScrollView {
            VStack(spacing: 16) {
                listHeroCard
                filterStrip
                deviceSectionContent(useButtons: true)
            }
            .padding()
        }
        .refreshable { await viewModel.load() }
    }

    private var iPhoneLayout: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                if viewModel.isLoading && viewModel.devices.isEmpty {
                    ProgressView().tint(AppColors.primary)
                } else if let error = viewModel.errorMessage, viewModel.devices.isEmpty {
                    EmptyStateView(icon: "exclamationmark.triangle", title: "加载失败", subtitle: error)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            listHeroCard
                            filterStrip
                            if scopedDevices.isEmpty {
                                if viewModel.devices.isEmpty {
                                    EmptyStateView(icon: "desktopcomputer", title: "暂无设备", subtitle: "添加设备")
                                } else if activeLane != nil {
                                    EmptyStateView(icon: "tray", title: "暂无设备", subtitle: "切换入口或筛选")
                                } else {
                                    EmptyStateView(icon: "magnifyingglass", title: "无结果", subtitle: "调整筛选")
                                }
                            } else {
                                deviceSectionContent(useButtons: false)
                            }
                        }
                        .padding()
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("设备")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "搜索设备...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { pairingButton }
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .sheet(isPresented: $showPairing) { PairingView() }
            .navigationDestination(for: Device.self) { device in
                DeviceDetailView(device: device)
            }
        }
    }

    private var listHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("设备")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)
            Text("设备列表")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textTitle)

            HStack(spacing: 8) {
                overviewChip("待关注 \(attentionDevices.count)", color: attentionDevices.isEmpty ? AppColors.disabled : AppColors.error)
                overviewChip("在线 \(onlineCount)", color: AppColors.success)
                overviewChip("正常 \(max(onlineCount - attentionDevices.filter(\.isOnline).count, 0))", color: AppColors.primary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                summaryTile(title: "总设备", value: "\(totalCount)", detail: "全部已接入机器", accent: AppColors.primary)
                summaryTile(title: "在线", value: "\(onlineCount)", detail: "当前可操作", accent: AppColors.success)
                summaryTile(title: "离线", value: "\(offlineCount)", detail: "待恢复", accent: AppColors.error)
                summaryTile(title: "禁用", value: "\(disabledCount)", detail: "已关闭", accent: AppColors.warning)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("工作入口")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if activeLane != nil {
                        Button("全部") {
                            self.activeLane = nil
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                    }
                }

                HStack(spacing: 10) {
                    laneCard(.alerts, count: alertCount, detail: "异常")
                    laneCard(.unread, count: unreadCount, detail: "未读")
                    laneCard(.offline, count: offlineLaneCount, detail: "离线")
                }
            }
        }
        .padding(20)
        .cardStyle()
    }

    private func summaryTile(title: String, value: String, detail: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(accent)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }

    private func overviewChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var filterStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("筛选")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(.all)
                    filterChip(.online)
                    filterChip(.offline)
                    filterChip(.disabled)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func deviceSectionContent(useButtons: Bool) -> some View {
        if scopedDevices.isEmpty {
            EmptyStateView(
                icon: activeLane == .unread ? "message.badge" : "tray",
                title: "当前入口没有设备",
                subtitle: "切换到其他工作入口，或调整筛选条件后重试。"
            )
        } else {
            deviceSections(useButtons: useButtons)
        }
    }

    private func filterChip(_ filter: DeviceFilter) -> some View {
        let isActive = viewModel.statusFilter == filter.statusValue
        return Button {
            viewModel.statusFilter = filter.statusValue
        } label: {
            Text(filter.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isActive ? AppColors.primary : AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isActive ? AppColors.primary.opacity(0.12) : Color.white.opacity(0.28))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isActive ? AppColors.primary.opacity(0.25) : AppColors.borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func laneCard(_ lane: WorkLane, count: Int, detail: String) -> some View {
        let isActive = activeLane == lane
        let accent = laneAccent(lane)

        return Button {
            activeLane = isActive ? nil : lane
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: lane.icon)
                    .font(.headline)
                    .foregroundStyle(accent)
                Text(lane.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(accent)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isActive ? accent.opacity(0.14) : Color.white.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .stroke(isActive ? accent.opacity(0.35) : AppColors.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func deviceSections(useButtons: Bool) -> some View {
        VStack(spacing: 14) {
            if !attentionDevices.isEmpty {
                sectionHeader("异常", detail: "\(attentionDevices.count) 台")
                ForEach(attentionDevices) { device in
                    deviceEntry(device, useButtons: useButtons, dimmed: false)
                }
            }

            let onlineRegular = regularDevices.filter { $0.status == 1 }
            if !onlineRegular.isEmpty {
                sectionHeader("在线", detail: "\(onlineRegular.count) 台")
                ForEach(onlineRegular) { device in
                    deviceEntry(device, useButtons: useButtons, dimmed: false)
                }
            }

            let offlineRegular = regularDevices.filter { $0.status != 1 }
            if !offlineRegular.isEmpty {
                sectionHeader("离线/禁用", detail: "\(offlineRegular.count) 台")
                ForEach(offlineRegular) { device in
                    deviceEntry(device, useButtons: useButtons, dimmed: true)
                }
            }
        }
    }

    @ViewBuilder
    private func deviceEntry(_ device: Device, useButtons: Bool, dimmed: Bool) -> some View {
        if useButtons {
            Button {
                viewModel.markMessagesRead(for: device.deviceId)
                selectedDevice = device
            } label: {
                DeviceCardView(device: device, unreadCount: viewModel.unreadCount(for: device.deviceId))
                    .opacity(dimmed ? 0.82 : 1)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: device) {
                DeviceCardView(device: device, unreadCount: viewModel.unreadCount(for: device.deviceId))
                    .opacity(dimmed ? 0.82 : 1)
            }
            .simultaneousGesture(TapGesture().onEnded {
                viewModel.markMessagesRead(for: device.deviceId)
            })
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textTitle)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func matchesLane(_ device: Device, lane: WorkLane) -> Bool {
        switch lane {
        case .alerts:
            return devicePriorityScore(device) > 0
        case .unread:
            return viewModel.unreadCount(for: device.deviceId) > 0
        case .offline:
            return device.status != 1
        }
    }

    private func laneAccent(_ lane: WorkLane) -> Color {
        switch lane {
        case .alerts:
            return AppColors.warning
        case .unread:
            return AppColors.error
        case .offline:
            return AppColors.disabled
        }
    }

    private var pairingButton: some View {
        Button { showPairing = true } label: {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AppColors.primary)
        }
    }

    private var filterMenu: some View {
        Menu {
            Button("全部") { viewModel.statusFilter = nil }
            Button("在线") { viewModel.statusFilter = 1 }
            Button("离线") { viewModel.statusFilter = 0 }
            Button("禁用") { viewModel.statusFilter = -1 }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(viewModel.statusFilter != nil ? AppColors.primary : AppColors.textSecondary)
        }
    }

    private func prioritizedDevices(from devices: [Device]) -> [Device] {
        devices
            .filter { devicePriorityScore($0) > 0 }
            .sorted {
                let lhs = devicePriorityScore($0)
                let rhs = devicePriorityScore($1)
                if lhs == rhs {
                    return ($0.lastHeartbeatAt ?? .distantPast) > ($1.lastHeartbeatAt ?? .distantPast)
                }
                return lhs > rhs
            }
    }

    private func devicePriorityScore(_ device: Device) -> Int {
        let info = OpenClawInfo.parse(from: device.extraData)
        let agentCount = info?.agents?.count ?? 0
        let onlineAgents = (info?.agents ?? []).filter(isAgentOnline).count

        if device.status == 0 { return 3 }
        if device.status == -1 { return 2 }
        if device.status == 1 && (agentCount == 0 || onlineAgents == 0) { return 1 }
        return 0
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
}

extension Device: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }
}
