import SwiftUI

struct TaskProgressView: View {
    let commandId: Int64
    @State private var client = TaskProgressClient()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        progressRing
                        stepsTimeline
                        snapshotSection
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("任务进度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(client.isConnected ? AppColors.success : AppColors.error)
                            .frame(width: 8, height: 8)
                            .shadow(color: (client.isConnected ? AppColors.success : AppColors.error).opacity(0.4), radius: 3)
                        Button("关闭") { dismiss() }
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
        }
        .task {
            await client.connect(commandId: commandId)
        }
        .onDisappear {
            client.disconnect()
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(AppColors.borderColor, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: client.latestProgress?.progressPercent ?? 0)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: client.latestProgress?.progress)

                VStack(spacing: 2) {
                    Text("\(client.latestProgress?.progress ?? 0)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(progressColor)
                    Text(client.latestProgress?.status ?? "等待")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if let step = client.latestProgress?.currentStep {
                Text(step)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
            }

            if let progress = client.latestProgress {
                Text("步骤 \(progress.completedSteps)/\(progress.totalSteps)")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var progressColor: Color {
        guard let progress = client.latestProgress else { return AppColors.textSecondary }
        if progress.isFailed { return AppColors.error }
        if progress.isCompleted { return AppColors.success }
        return AppColors.primary
    }

    // MARK: - Steps Timeline

    @ViewBuilder
    private var stepsTimeline: some View {
        if !client.progressHistory.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("进度历史")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
                    .padding(.bottom, 12)

                ForEach(Array(client.progressHistory.enumerated()), id: \.element.id) { index, progress in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(stepColor(progress))
                                .frame(width: 10, height: 10)
                                .shadow(color: stepColor(progress).opacity(0.3), radius: 3)

                            if index < client.progressHistory.count - 1 {
                                Rectangle()
                                    .fill(AppColors.borderColor)
                                    .frame(width: 1, height: 40)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(progress.currentStep ?? "步骤 \(progress.completedSteps)")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textPrimary)

                            HStack(spacing: 8) {
                                Text("\(progress.progress)%")
                                    .font(.caption)
                                    .foregroundStyle(stepColor(progress))
                                Text(progress.createdAt.shortString)
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        Spacer()
                    }
                }
            }
            .padding()
            .cardStyle()
        }
    }

    private func stepColor(_ progress: TaskProgress) -> Color {
        if progress.isFailed { return AppColors.error }
        if progress.isCompleted { return AppColors.success }
        if progress.isRunning { return AppColors.primary }
        return AppColors.textSecondary
    }

    // MARK: - Snapshot Section

    @ViewBuilder
    private var snapshotSection: some View {
        let snapshotItems = client.progressHistory.filter { $0.snapshotUrl != nil }
        if !snapshotItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("快照")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(snapshotItems) { item in
                            if let urlStr = item.snapshotUrl, let url = snapshotURL(urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 160, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                                    case .failure:
                                        placeholderThumbnail
                                    default:
                                        ProgressView()
                                            .frame(width: 160, height: 100)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .cardStyle()
        }
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
            .fill(AppColors.bgGlass)
            .frame(width: 160, height: 100)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(AppColors.textSecondary)
            )
    }

    private func snapshotURL(_ path: String) -> URL? {
        if path.starts(with: "http") {
            return URL(string: path)
        }
        return URL(string: "\(AppConfig.baseURL.replacingOccurrences(of: "/api/v1", with: ""))\(path)")
    }
}
