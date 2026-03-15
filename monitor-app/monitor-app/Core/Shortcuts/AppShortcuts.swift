import AppIntents

// MARK: - Check Device Status Shortcut

struct CheckDeviceStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "查看设备状态"
    static var description: IntentDescription = "查看灵控台设备状态"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let overview: DeviceWorkspaceOverview = try await APIClient.shared.request(.dashboard)
            let s = overview.deviceSummary
            return .result(
                dialog: "共 \(s.total) 台设备，在线 \(s.online)，离线 \(s.offline)。"
            )
        } catch {
            return .result(dialog: "无法获取设备状态，请检查网络或登录。")
        }
    }
}

// MARK: - Send Restart Command Shortcut

struct SendRestartCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "重启设备"
    static var description: IntentDescription = "向指定设备发送重启命令"
    static var openAppWhenRun = true

    @Parameter(title: "设备名称")
    var deviceName: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let name = deviceName, !name.isEmpty else {
            return .result(dialog: "请指定设备名称。")
        }

        do {
            let devices: [Device] = try await APIClient.shared.request(
                .devices,
                queryItems: [
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "page_size", value: "100"),
                ]
            )

            guard let device = devices.first(where: {
                $0.hostname.localizedCaseInsensitiveContains(name)
            }) else {
                return .result(dialog: "未找到名称包含「\(name)」的设备。")
            }

            guard device.isOnline else {
                return .result(dialog: "\(device.hostname) 当前离线，无法发送命令。")
            }

            return .result(dialog: "已打开 App，请在设备详情中确认重启命令。")
        } catch {
            return .result(dialog: "操作失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - App Shortcuts Provider

struct OpenClawShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckDeviceStatusIntent(),
            phrases: [
                "查看 \(.applicationName) 设备状态",
                "检查 \(.applicationName) 设备状态",
                "\(.applicationName) 设备情况",
            ],
            shortTitle: "设备状态",
            systemImageName: "desktopcomputer"
        )
        AppShortcut(
            intent: SendRestartCommandIntent(),
            phrases: [
                "用 \(.applicationName) 重启设备",
                "\(.applicationName) 重启设备",
            ],
            shortTitle: "重启设备",
            systemImageName: "arrow.clockwise.circle"
        )
    }
}
