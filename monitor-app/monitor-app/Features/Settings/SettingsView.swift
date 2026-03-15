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
    @State private var showLogoutConfirm = false
    @State private var activeSheet: SettingsSheet?
    @State private var copied = false

    private var accountName: String {
        AuthManager.shared.currentAdmin?.nickname ?? "用户"
    }

    private var accountEmail: String {
        AuthManager.shared.currentAdmin?.email ?? ""
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
                                subtitle: "在 macOS 终端安装灵控台助手",
                                tint: AppColors.primary
                            ) {
                                activeSheet = .installCommand
                            }
                            groupedActionRow(
                                icon: "trash",
                                title: "卸载命令",
                                subtitle: "移除灵控台助手",
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

                        sectionBlock(title: "关于") {
                            groupedInfoRow(icon: "app.badge", title: "版本", subtitle: appVersionText, tint: AppColors.primary)
                            groupedInfoRow(icon: "cpu", title: "兼容设备", subtitle: "已安装 OpenClaw 的设备", tint: AppColors.textSecondary)
                            groupedInfoRow(icon: "iphone", title: "最低版本", subtitle: "iOS 16.0", tint: AppColors.textSecondary)
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
                        footnote: "用于移除灵控台助手，不会删除 OpenClaw 主数据目录。"
                    )
                case .pairingHelp:
                    PairingHelpSheet()
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
                Text("我的设备账号")
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
        monospaced: Bool = false
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

        if title != "最低版本" && title != "当前支持平台" && title != "消息加密" {
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

        if title != "退出登录" {
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
