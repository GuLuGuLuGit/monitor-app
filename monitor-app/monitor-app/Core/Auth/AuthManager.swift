import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()

    private static let demoModeKey = "auth.isDemoMode"

    private(set) var isAuthenticated = false
    private(set) var currentAdmin: AdminInfo?
    private(set) var isLoading = false
    private(set) var isDemoMode = false

    private init() {}

    static let demoUsername = DemoModeStore.demoUsername
    static let demoPassword = DemoModeStore.demoPassword

    private static let demoAdmin = AdminInfo(
        id: 9_999,
        username: demoUsername,
        email: "demo@lingkong.local",
        nickname: "演示账号",
        role: "user",
        lastLoginAt: nil,
        lastLoginIp: nil
    )

    func checkAuthState() async {
        if UserDefaults.standard.bool(forKey: Self.demoModeKey) {
            isDemoMode = true
            currentAdmin = Self.demoAdmin
            isAuthenticated = true
            WidgetSnapshotStore.save(devices: DemoModeStore.shared.devices())
            return
        }

        guard let token = await KeychainStore.shared.getToken(), !token.isEmpty else {
            currentAdmin = nil
            isAuthenticated = false
            isDemoMode = false
            return
        }

        do {
            let admin: AdminInfo = try await APIClient.shared.request(.me)
            currentAdmin = admin
            isAuthenticated = true
            isDemoMode = false
        } catch let error as APIError {
            if case .unauthorized = error {
                isAuthenticated = false
                isDemoMode = false
                await KeychainStore.shared.clearAll()
                WidgetSnapshotStore.clear()
                return
            }
            isAuthenticated = true
            isDemoMode = false
        } catch {
            isAuthenticated = true
            isDemoMode = false
        }
    }

    func login(username: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        if username == Self.demoUsername && password == Self.demoPassword {
            await KeychainStore.shared.clearAll()
            DemoModeStore.shared.reset()
            UserDefaults.standard.set(true, forKey: Self.demoModeKey)
            currentAdmin = Self.demoAdmin
            isAuthenticated = true
            isDemoMode = true
            WidgetSnapshotStore.save(devices: DemoModeStore.shared.devices())
            return
        }

        let request = LoginRequest(username: username, password: password)
        let response: LoginResponse = try await APIClient.shared.request(.login, body: request)

        UserDefaults.standard.removeObject(forKey: Self.demoModeKey)
        await KeychainStore.shared.saveToken(response.token)
        currentAdmin = response.admin
        isAuthenticated = true
        isDemoMode = false
    }

    func setAuthenticated(admin: AdminInfo) {
        UserDefaults.standard.removeObject(forKey: Self.demoModeKey)
        currentAdmin = admin
        isAuthenticated = true
        isDemoMode = false
    }

    func logout() async {
        await clearSession(resetDemoStore: false)
    }

    func handleUnauthorized() async {
        await clearSession(resetDemoStore: false)
    }

    func deleteAccount() async throws {
        if isDemoMode {
            await clearSession(resetDemoStore: true)
            return
        }

        try await APIClient.shared.requestVoid(.deleteAccount)
        await clearSession(resetDemoStore: false)
    }

    private func clearSession(resetDemoStore: Bool) async {
        await KeychainStore.shared.clearAll()
        UserDefaults.standard.removeObject(forKey: Self.demoModeKey)
        if resetDemoStore {
            DemoModeStore.shared.reset()
        }
        currentAdmin = nil
        isAuthenticated = false
        isDemoMode = false
        WidgetSnapshotStore.clear()
    }
}
