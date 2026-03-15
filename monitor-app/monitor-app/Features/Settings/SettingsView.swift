import SwiftUI

struct SettingsView: View {
    private let topContentSpacing: CGFloat = 8
    @State private var serverURL = AppConfig.baseURL
    @State private var biometric = BiometricAuth.shared
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                List {
                    profileSection
                    securitySection
                    serverSection
                    aboutSection
                    logoutSection
                }
                .scrollContentBackground(.hidden)
                .listSectionSpacing(12)
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: topContentSpacing)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.gradientPrimary)
                        .frame(width: 42, height: 42)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 6)
                    Text(String((AuthManager.shared.currentAdmin?.nickname ?? "A").prefix(1)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(AuthManager.shared.currentAdmin?.nickname ?? "用户")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(AuthManager.shared.currentAdmin?.email ?? "")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    if let role = AuthManager.shared.currentAdmin?.role {
                        Text(role.lowercased() == "admin" ? "用户" : role)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(minHeight: AppTheme.topModuleMinHeight, alignment: .leading)
            .padding(.vertical, 2)
            .listRowBackground(settingsRowBackground())
            .listRowInsets(EdgeInsets(top: 8, leading: AppTheme.pageHorizontalPadding, bottom: 8, trailing: AppTheme.pageHorizontalPadding))
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section("安全") {
            if biometric.isAvailable {
                Toggle(isOn: $biometric.isEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(biometric.biometricName)
                                .foregroundStyle(AppColors.textPrimary)
                            Text("进入 App 时要求验证")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    } icon: {
                        Image(systemName: biometric.biometricIcon)
                            .foregroundStyle(AppColors.primary)
                    }
                }
                .tint(AppColors.primary)
                .listRowBackground(settingsRowBackground())
            }

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("端到端加密")
                        .foregroundStyle(AppColors.textPrimary)
                    Text("RSA-OAEP + AES-256-GCM")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(AppColors.success)
            }
            .listRowBackground(settingsRowBackground())
        }
    }

    // MARK: - Server

    private var serverSection: some View {
        Section("服务器") {
            VStack(alignment: .leading, spacing: 6) {
                Text("API 地址")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)

                HStack {
                    Image(systemName: "server.rack")
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 20)

                    TextField("https://your-server.com/api/v1", text: $serverURL)
                        .foregroundStyle(AppColors.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.subheadline)
                        .monospaced()
                }
            }
            .listRowBackground(settingsRowBackground())

            Button {
                AppConfig.baseURL = serverURL
                ToastManager.shared.success("服务器地址已更新")
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("保存并重连")
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.primary)
            }
            .listRowBackground(settingsRowBackground())
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("关于") {
            aboutRow(icon: "app.badge", label: "版本", value: "1.0.0 (1)")
            aboutRow(icon: "swift", label: "框架", value: "SwiftUI + MVVM")
            aboutRow(icon: "iphone", label: "最低版本", value: "iOS 16.0")
            aboutRow(icon: "shield.checkered", label: "加密", value: "CryptoKit + Security.framework")
        }
    }

    private func aboutRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .listRowBackground(settingsRowBackground())
    }

    // MARK: - Logout

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                showLogoutConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("退出登录")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .listRowBackground(settingsRowBackground(AppColors.error.opacity(0.12)))
            .alert("确认退出", isPresented: $showLogoutConfirm) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    Task { await AuthManager.shared.logout() }
                }
            } message: {
                Text("退出后需要重新登录才能使用。")
            }
        }
    }

    private func settingsRowBackground(_ color: Color = Color.white.opacity(0.35)) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            .fill(color)
    }
}
