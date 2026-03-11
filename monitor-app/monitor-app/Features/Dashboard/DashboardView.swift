import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.bgPrimary.ignoresSafeArea()

                if viewModel.isLoading && viewModel.dashboardData == nil {
                    ProgressView()
                        .tint(AppColors.primary)
                } else if let error = viewModel.errorMessage, viewModel.dashboardData == nil {
                    EmptyStateView(icon: "exclamationmark.triangle", title: "加载失败", subtitle: error)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            deviceSummarySection
                            taskSummarySection
                            recentDevicesSection
                        }
                        .padding()
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await viewModel.load()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    // MARK: - Device Summary

    @ViewBuilder
    private var deviceSummarySection: some View {
        if let summary = viewModel.dashboardData?.deviceSummary {
            VStack(alignment: .leading, spacing: 12) {
                Text("设备概览")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    StatCardView(
                        title: "设备总数",
                        value: "\(summary.total)",
                        icon: "desktopcomputer",
                        color: AppColors.primary,
                        gradient: AppColors.gradientPrimary
                    )
                    StatCardView(
                        title: "在线",
                        value: "\(summary.online)",
                        icon: "checkmark.circle.fill",
                        color: AppColors.success,
                        gradient: AppColors.gradientSuccess
                    )
                    StatCardView(
                        title: "离线",
                        value: "\(summary.offline)",
                        icon: "xmark.circle.fill",
                        color: AppColors.error,
                        gradient: AppColors.gradientError
                    )
                    StatCardView(
                        title: "禁用",
                        value: "\(summary.disabled)",
                        icon: "minus.circle.fill",
                        color: AppColors.disabled
                    )
                }
            }
        }
    }

    // MARK: - Task Summary

    @ViewBuilder
    private var taskSummarySection: some View {
        if let stats = viewModel.taskStats {
            VStack(alignment: .leading, spacing: 12) {
                Text("任务概览")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    miniStat(title: "执行中", value: "\(stats.running)", color: AppColors.primary)
                    miniStat(title: "已完成", value: "\(stats.completed)", color: AppColors.success)
                    miniStat(title: "失败", value: "\(stats.failed)", color: AppColors.error)
                }
            }
        }
    }

    private func miniStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .cardStyle()
    }

    // MARK: - Recent Devices

    @ViewBuilder
    private var recentDevicesSection: some View {
        if let devices = viewModel.dashboardData?.recentDevices, !devices.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("最近设备")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)

                ForEach(devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: "desktopcomputer")
                            .font(.title3)
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.hostname)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.textPrimary)

                            Text(device.osVersion)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        Spacer()

                        StatusBadge.deviceStatus(device.status)
                    }
                    .padding()
                    .cardStyle()
                }
            }
        }
    }
}
