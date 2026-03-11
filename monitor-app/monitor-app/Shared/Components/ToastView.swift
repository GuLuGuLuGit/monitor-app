import SwiftUI
import Observation

enum ToastType {
    case success, error, warning, info

    var icon: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: AppColors.success
        case .error: AppColors.error
        case .warning: AppColors.warning
        case .info: AppColors.primary
        }
    }
}

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let message: String

    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
@MainActor
final class ToastManager {
    static let shared = ToastManager()

    var currentToast: ToastItem?

    private init() {}

    func show(_ type: ToastType, message: String, duration: TimeInterval = 3) {
        withAnimation(.spring(response: 0.3)) {
            currentToast = ToastItem(type: type, message: message)
        }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            withAnimation(.easeOut(duration: 0.2)) {
                currentToast = nil
            }
        }
    }

    func success(_ message: String) { show(.success, message: message) }
    func error(_ message: String) { show(.error, message: message, duration: 4) }
    func warning(_ message: String) { show(.warning, message: message) }
    func info(_ message: String) { show(.info, message: message) }
}

struct ToastOverlay: View {
    @State private var toastManager = ToastManager.shared

    var body: some View {
        VStack {
            if let toast = toastManager.currentToast {
                HStack(spacing: 10) {
                    Image(systemName: toast.type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(toast.type.color)

                    Text(toast.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Button {
                        withAnimation { toastManager.currentToast = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    AppColors.bgCardHover
                        .overlay(toast.type.color.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(toast.type.color.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: toast.type.color.opacity(0.2), radius: 12, y: 4)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.spring(response: 0.3), value: toastManager.currentToast)
        .allowsHitTesting(toastManager.currentToast != nil)
    }
}

struct ToastModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            ToastOverlay()
        }
    }
}

extension View {
    func withToast() -> some View {
        modifier(ToastModifier())
    }
}
