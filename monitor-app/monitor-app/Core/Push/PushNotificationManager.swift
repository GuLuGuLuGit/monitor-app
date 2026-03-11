import Foundation
import UserNotifications
import UIKit
import Observation

@Observable
@MainActor
final class PushNotificationManager: NSObject, @preconcurrency Sendable {
    static let shared = PushNotificationManager()

    private(set) var isAuthorized = false
    private(set) var deviceToken: String?

    private override init() {
        super.init()
    }

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                await registerForRemoteNotifications()
                setupNotificationCategories()
            }
        } catch {
            isAuthorized = false
        }
    }

    private func registerForRemoteNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        Task { await uploadToken(token) }
    }

    func handleRegistrationError(_ error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    private func uploadToken(_ token: String) async {
        struct PushTokenRequest: Encodable {
            let deviceToken: String
            let platform: String

            enum CodingKeys: String, CodingKey {
                case deviceToken = "device_token"
                case platform
            }
        }

        do {
            try await APIClient.shared.requestVoid(
                .registerPushToken,
                body: PushTokenRequest(deviceToken: token, platform: "ios")
            )
        } catch {}
    }

    private func setupNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_DEVICE",
            title: "查看设备",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "忽略",
            options: [.destructive]
        )

        let deviceCategory = UNNotificationCategory(
            identifier: "DEVICE_STATUS",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let commandCategory = UNNotificationCategory(
            identifier: "COMMAND_STATUS",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([deviceCategory, commandCategory])
    }
}
