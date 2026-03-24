import SwiftUI

struct ContentView: View {
    @State private var authManager = AuthManager.shared
    @State private var biometric = BiometricAuth.shared
    @State private var isCheckingAuth = true

    var body: some View {
        Group {
            if isCheckingAuth {
                splashView
            } else if !authManager.isAuthenticated {
                NavigationStack {
                    LoginView()
                }
            } else if biometric.isLocked {
                lockScreen
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(.light)
        .task {
            await authManager.checkAuthState()
            if authManager.isAuthenticated && !authManager.isDemoMode {
                await PushNotificationManager.shared.requestAuthorization()
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                isCheckingAuth = false
            }
        }
    }

    private var splashView: some View {
        ZStack {
            AppColors.gradientBg.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.gradientPrimary)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 12)

                ProgressView()
                    .tint(AppColors.primary)
            }
        }
    }

    private var lockScreen: some View {
        ZStack {
            AppColors.gradientBg.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.primary)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 12)

                Text("爪群已锁定")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textTitle)

                Button {
                    Task { _ = await biometric.authenticate() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: biometric.biometricIcon)
                        Text("使用 \(biometric.biometricName) 解锁")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppColors.gradientPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 8)
                }
            }
        }
        .task {
            _ = await biometric.authenticate()
        }
    }
}

struct MainTabView: View {
    @StateObject private var router = DeepLinkRouter.shared
    @State private var authManager = AuthManager.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            DeviceListView()
                .tabItem {
                    Label("设备", systemImage: "desktopcomputer")
                }
                .tag(0)

            CommandListView()
                .tabItem {
                    Label("命令", systemImage: "terminal.fill")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(AppColors.primary)
        .safeAreaInset(edge: .top) {
            if authManager.isDemoMode {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.rectangle.badge.checkmark")
                    Text("演示模式：当前数据为本地测试数据，不会操作真实设备")
                        .lineLimit(2)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.88))
                .overlay(alignment: .bottom) {
                    Divider().background(AppColors.borderColor)
                }
            }
        }
    }
}
