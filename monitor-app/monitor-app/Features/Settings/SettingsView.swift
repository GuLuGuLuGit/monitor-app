import SwiftUI

struct SettingsView: View {
    private let topContentSpacing: CGFloat = 8

    private enum SettingsSheet: Identifiable {
        case addDevice
        case installCommand
        case uninstallCommand
        case pairingHelp

        var id: String {
            switch self {
            case .addDevice: return "add-device"
            case .installCommand: return "install-command"
            case .uninstallCommand: return "uninstall-command"
            case .pairingHelp: return "pairing-help"
            }
        }
    }

    @State private var biometric = BiometricAuth.shared
    @State private var authManager = AuthManager.shared
    @State private var showLogoutConfirm = false
    @State private var showDeleteSheet = false
    @State private var activeSheet: SettingsSheet?
    @State private var copied = false

    private var accountName: String {
        AuthManager.shared.currentAdmin?.nickname ?? "用户"
    }

    private var installCommand: String {
        let base = AppConfig.baseURL.replacingOccurrences(of: "/api/v1", with: "")
        return "curl -fsSL \(base)/install.sh | bash -s -- --server \(base)"
    }

    private var uninstallCommand: String {
        let base = AppConfig.baseURL.replacingOccurrences(of: "/api/v1", with: "")
        return "curl -fsSL \(base)/uninstall.sh | bash"
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        topProfileCard
                        sectionBlock(title: "账号") {
                            groupedInfoRow(
                                icon: "person.text.rectangle",
                                title: authManager.isDemoMode ? "当前身份" : "登录账号",
                                subtitle: authManager.isDemoMode ? "演示模式（仅本地示例数据）" : (authManager.currentAdmin?.email ?? authManager.currentAdmin?.username ?? "当前已登录"),
                                tint: AppColors.primary,
                                showsDivider: true
                            )
                            groupedActionRow(
                                icon: "person.crop.circle.badge.minus",
                                title: "删除账号",
                                subtitle: authManager.isDemoMode ? "清除本地演示数据并退出当前演示账号" : "永久删除账号、已绑定设备、命令历史与消息记录",
                                tint: AppColors.error,
                                destructive: true,
                                showsDivider: false
                            ) {
                                showDeleteSheet = true
                            }
                        }
                        sectionBlock(title: "安全") {
                            if biometric.isAvailable {
                                groupedToggleRow(
                                    icon: biometric.biometricIcon,
                                    title: biometric.biometricName,
                                    subtitle: "进入 App 时验证",
                                    tint: AppColors.primary,
                                    isOn: $biometric.isEnabled
                                )
                            }
                            groupedInfoRow(
                                icon: "lock.shield.fill",
                                title: "消息加密",
                                subtitle: "RSA-OAEP + AES-256-GCM",
                                tint: AppColors.success
                            )
                        }

                        sectionBlock(title: "设备接入") {
                            if authManager.isDemoMode {
                                groupedInfoRow(
                                    icon: "sparkles.rectangle.stack",
                                    title: "演示模式",
                                    subtitle: "当前账号使用本地测试数据，安装与配对入口已关闭",
                                    tint: AppColors.primary
                                )
                            } else {
                                groupedActionRow(
                                    icon: "link.badge.plus",
                                    title: "添加设备",
                                    subtitle: "输入配对码，将设备添加到我的设备",
                                    tint: AppColors.primary
                                ) {
                                    activeSheet = .addDevice
                                }
                                groupedActionRow(
                                    icon: "terminal",
                                    title: "安装命令",
                                    subtitle: "在 macOS 终端安装爪群助手",
                                    tint: AppColors.primary
                                ) {
                                    activeSheet = .installCommand
                                }
                                groupedActionRow(
                                    icon: "trash",
                                    title: "卸载命令",
                                    subtitle: "移除爪群助手",
                                    tint: AppColors.textSecondary
                                ) {
                                    activeSheet = .uninstallCommand
                                }
                                groupedActionRow(
                                    icon: "questionmark.circle",
                                    title: "配对说明",
                                    subtitle: "查看安装、配对和绑定步骤",
                                    tint: AppColors.textSecondary
                                ) {
                                    activeSheet = .pairingHelp
                                }
                                groupedInfoRow(
                                    icon: "laptopcomputer",
                                    title: "当前支持平台",
                                    subtitle: "macOS",
                                    tint: AppColors.primary
                                )
                            }
                        }

                        sectionBlock(title: "关于") {
                            groupedInfoRow(icon: "app.badge", title: "版本", subtitle: appVersionText, tint: AppColors.primary)
                            groupedInfoRow(icon: "cpu", title: "兼容设备", subtitle: "已安装 OpenClaw 的设备", tint: AppColors.textSecondary)
                            groupedInfoRow(icon: "iphone", title: "最低版本", subtitle: "iOS 17.0", tint: AppColors.textSecondary)
                        }

                        sectionBlock(title: nil) {
                            groupedActionRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "退出登录",
                                subtitle: "结束当前账号会话",
                                tint: AppColors.error,
                                destructive: true
                            ) {
                                showLogoutConfirm = true
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.pageHorizontalPadding)
                    .padding(.vertical, 16)
                    .padding(.top, topContentSpacing)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addDevice:
                    PairingView()
                case .installCommand:
                    CommandSheet(
                        title: "安装命令",
                        command: installCommand,
                        footnote: "当前仅支持 macOS。安装后终端会显示配对码。"
                    )
                case .uninstallCommand:
                    CommandSheet(
                        title: "卸载命令",
                        command: uninstallCommand,
                        footnote: "用于移除爪群助手，不会删除 OpenClaw 主数据目录。"
                    )
                case .pairingHelp:
                    PairingHelpSheet()
                }
            }
            .sheet(isPresented: $showDeleteSheet) {
                AccountDeletionSheet(
                    isDemoMode: authManager.isDemoMode,
                    accountName: accountName,
                    accountIdentifier: authManager.currentAdmin?.email ?? authManager.currentAdmin?.username
                ) {
                    do {
                        try await AuthManager.shared.deleteAccount()
                        return nil
                    } catch let error as APIError {
                        return error.errorDescription ?? "删除失败，请稍后重试"
                    } catch {
                        return error.localizedDescription
                    }
                }
            }
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

    private var topProfileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.gradientPrimary)
                    .frame(width: 42, height: 42)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 6)
                Text(String(accountName.prefix(1)))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(accountName)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(authManager.isDemoMode ? "演示账号" : "我的设备账号")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.primary.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: AppTheme.topModuleMinHeight)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppColors.borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sectionBlock<Content: View>(title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 4)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppColors.borderColor, lineWidth: 1)
            )
        }
    }

    private func rowDivider() -> some View {
        Rectangle()
            .fill(AppColors.borderColor.opacity(0.9))
            .frame(height: 1)
            .padding(.leading, 46)
    }

    @ViewBuilder
    private func groupedInfoRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        monospaced: Bool = false,
        showsDivider: Bool = true
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(AppColors.textPrimary)
                Group {
                    if monospaced {
                        Text(subtitle).monospaced()
                    } else {
                        Text(subtitle)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(monospaced ? 1 : 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)

        if showsDivider {
            rowDivider()
        }
    }

    @ViewBuilder
    private func groupedActionRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        destructive: Bool = false,
        showsDivider: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(destructive ? AppColors.error : AppColors.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if showsDivider {
            rowDivider()
        }
    }

    @ViewBuilder
    private func groupedToggleRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .tint(AppColors.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)

        rowDivider()
    }
}

private struct AccountDeletionSheet: View {
    let isDemoMode: Bool
    let accountName: String
    let accountIdentifier: String?
    let onConfirm: () async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var confirmationText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var confirmKeyword: String { "DELETE" }

    private var canSubmit: Bool {
        !isSubmitting && confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == confirmKeyword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(isDemoMode ? "清除演示数据" : "删除账号")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppColors.textTitle)
                            Text(isDemoMode ? "这会移除当前设备上的演示数据，并立即退出演示模式。" : "这会永久删除当前账号以及该账号下的设备、命令记录、消息记录和相关配置。删除后无法恢复。")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            infoRow(title: "账号名称", value: accountName)
                            if let accountIdentifier, !accountIdentifier.isEmpty {
                                infoRow(title: "账号标识", value: accountIdentifier)
                            }
                            infoRow(title: "确认方式", value: "输入 \(confirmKeyword) 后才能继续")
                        }
                        .padding()
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("确认删除")
                                .font(.headline)
                                .foregroundStyle(AppColors.textTitle)

                            TextField(confirmKeyword, text: $confirmationText)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                        .stroke(AppColors.borderColor, lineWidth: 1)
                                )

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.error)
                            }

                            Button {
                                Task {
                                    isSubmitting = true
                                    errorMessage = nil
                                    if let error = await onConfirm() {
                                        errorMessage = error
                                        isSubmitting = false
                                        return
                                    }
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if isSubmitting {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    }
                                    Text(isDemoMode ? "清除并退出" : "确认删除账号")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    canSubmit
                                        ? AppColors.gradientError
                                        : LinearGradient(colors: [AppColors.disabled], startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                            }
                            .disabled(!canSubmit)
                        }
                        .padding()
                        .cardStyle()
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(isDemoMode ? "清除演示数据" : "删除账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .foregroundStyle(AppColors.textPrimary)
                .textSelection(.enabled)
        }
    }
}

private struct CommandSheet: View {
    let title: String
    let command: String
    let footnote: String

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppColors.textTitle)
                        Text(footnote)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding()
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(command)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .stroke(AppColors.borderColor, lineWidth: 1)
                            )

                        Button {
                            UIPasteboard.general.string = command
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            Text(copied ? "已复制" : "复制命令")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.gradientPrimary)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                        }
                    }
                    .padding()
                    .cardStyle()

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PairingHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        helpCard(number: 1, title: "安装助手", detail: "在目标 macOS 设备终端执行安装命令。")
                        helpCard(number: 2, title: "查看配对码", detail: "安装完成后，终端会直接显示 6 位配对码。")
                        helpCard(number: 3, title: "添加设备", detail: "回到 App，进入“添加设备”并输入配对码。")
                        helpCard(number: 4, title: "开始管理", detail: "绑定成功后，即可查看状态、发送命令，并与 Agent 交互。")
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("配对说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func helpCard(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppColors.gradientPrimary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textTitle)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .cardStyle()
    }
}
