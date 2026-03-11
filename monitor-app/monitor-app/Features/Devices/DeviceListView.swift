import SwiftUI

struct DeviceListView: View {
    @State private var viewModel = DeviceListViewModel()
    @State private var showPairing = false
    @State private var selectedDevice: Device?
    @Environment(\.horizontalSizeClass) private var sizeClass

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

    // MARK: - iPad: NavigationSplitView

    private var iPadLayout: some View {
        NavigationSplitView {
            ZStack {
                AppColors.bgPrimary.ignoresSafeArea()
                sidebarContent
            }
            .navigationTitle("设备")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $viewModel.searchText, prompt: "搜索设备...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    pairingButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .sheet(isPresented: $showPairing) { PairingView() }
        } detail: {
            ZStack {
                AppColors.bgPrimary.ignoresSafeArea()
                if let device = selectedDevice {
                    DeviceDetailView(device: device)
                } else {
                    EmptyStateView(icon: "sidebar.left", title: "选择设备", subtitle: "在左侧列表中选择一个设备查看详情")
                }
            }
        }
    }

    private var sidebarContent: some View {
        Group {
            if viewModel.isLoading && viewModel.devices.isEmpty {
                ProgressView().tint(AppColors.primary)
            } else if viewModel.filteredDevices.isEmpty {
                EmptyStateView(icon: "desktopcomputer", title: "暂无设备")
            } else {
                List(selection: $selectedDevice) {
                    if !viewModel.onlineDevices.isEmpty {
                        Section("在线 (\(viewModel.onlineDevices.count))") {
                            ForEach(viewModel.onlineDevices) { device in
                                sidebarRow(device)
                                    .tag(device)
                            }
                        }
                    }
                    if !viewModel.offlineDevices.isEmpty {
                        Section("离线/禁用 (\(viewModel.offlineDevices.count))") {
                            ForEach(viewModel.offlineDevices) { device in
                                sidebarRow(device)
                                    .tag(device)
                                    .opacity(0.7)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.sidebar)
                .refreshable { await viewModel.load() }
            }
        }
    }

    private func sidebarRow(_ device: Device) -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "desktopcomputer")
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
                Circle()
                    .fill(Color.deviceStatusColor(device.status))
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.hostname)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(device.osVersion)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .listRowBackground(AppColors.bgCard)
    }

    // MARK: - iPhone: NavigationStack

    private var iPhoneLayout: some View {
        NavigationStack {
            ZStack {
                AppColors.bgPrimary.ignoresSafeArea()

                if viewModel.isLoading && viewModel.devices.isEmpty {
                    ProgressView().tint(AppColors.primary)
                } else if let error = viewModel.errorMessage, viewModel.devices.isEmpty {
                    EmptyStateView(icon: "exclamationmark.triangle", title: "加载失败", subtitle: error)
                } else if viewModel.filteredDevices.isEmpty {
                    if viewModel.devices.isEmpty {
                        EmptyStateView(icon: "desktopcomputer", title: "暂无设备", subtitle: "请先配对设备")
                    } else {
                        EmptyStateView(icon: "magnifyingglass", title: "无匹配结果")
                    }
                } else {
                    deviceList
                }
            }
            .navigationTitle("设备")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $viewModel.searchText, prompt: "搜索设备...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { pairingButton }
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .sheet(isPresented: $showPairing) { PairingView() }
        }
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !viewModel.onlineDevices.isEmpty {
                    sectionHeader("在线 (\(viewModel.onlineDevices.count))", color: AppColors.success)
                    ForEach(viewModel.onlineDevices) { device in
                        NavigationLink(value: device) {
                            DeviceCardView(device: device)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !viewModel.offlineDevices.isEmpty {
                    sectionHeader("离线/禁用 (\(viewModel.offlineDevices.count))", color: AppColors.textSecondary)
                    ForEach(viewModel.offlineDevices) { device in
                        NavigationLink(value: device) {
                            DeviceCardView(device: device)
                                .opacity(0.7)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .refreshable { await viewModel.load() }
        .navigationDestination(for: Device.self) { device in
            DeviceDetailView(device: device)
        }
    }

    // MARK: - Shared

    private var pairingButton: some View {
        Button { showPairing = true } label: {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AppColors.primary)
        }
    }

    private func sectionHeader(_ title: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var filterMenu: some View {
        Menu {
            Button {
                viewModel.statusFilter = nil
            } label: {
                Label("全部", systemImage: viewModel.statusFilter == nil ? "checkmark" : "")
            }
            Button {
                viewModel.statusFilter = 1
            } label: {
                Label("在线", systemImage: viewModel.statusFilter == 1 ? "checkmark" : "")
            }
            Button {
                viewModel.statusFilter = 0
            } label: {
                Label("离线", systemImage: viewModel.statusFilter == 0 ? "checkmark" : "")
            }
            Button {
                viewModel.statusFilter = -1
            } label: {
                Label("禁用", systemImage: viewModel.statusFilter == -1 ? "checkmark" : "")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(viewModel.statusFilter != nil ? AppColors.primary : AppColors.textSecondary)
        }
    }
}

extension Device: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }
}
