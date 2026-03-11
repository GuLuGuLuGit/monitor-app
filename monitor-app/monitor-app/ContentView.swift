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
                LoginView()
            } else if biometric.isLocked {
                lockScreen
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await authManager.checkAuthState()
            if authManager.isAuthenticated {
                await PushNotificationManager.shared.requestAuthorization()
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                isCheckingAuth = false
            }
        }
    }

    private var splashView: some View {
        ZStack {
            AppColors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.gradientPrimary)

                ProgressView()
                    .tint(AppColors.primary)
            }
        }
    }

    private var lockScreen: some View {
        ZStack {
            AppColors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.primary)

                Text("OpenClaw 已锁定")
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
                }
            }
        }
        .task {
            _ = await biometric.authenticate()
        }
    }
}

struct MainTabView: View {
    @State private var router = DeepLinkRouter.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill", value: 0) {
                DashboardView()
            }
            Tab("设备", systemImage: "desktopcomputer", value: 1) {
                DeviceListView()
            }
            Tab("命令", systemImage: "terminal.fill", value: 2) {
                CommandListView()
            }
            Tab("设置", systemImage: "gearshape.fill", value: 3) {
                SettingsView()
            }
        }
        .tint(AppColors.primary)
    }
}
