import SwiftUI

struct LoadingOverlay: View {
    var message: String = "加载中..."

    var body: some View {
        ZStack {
            Color.white.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppColors.primary)
                    .scaleEffect(1.2)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .padding(32)
            .cardStyle()
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textSecondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textSecondary)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.error)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)

            Spacer()

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(AppColors.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                .stroke(AppColors.error.opacity(0.25), lineWidth: 1)
        )
    }
}
