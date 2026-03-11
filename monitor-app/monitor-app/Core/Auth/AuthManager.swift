import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()

    private(set) var isAuthenticated = false
    private(set) var currentAdmin: AdminInfo?
    private(set) var isLoading = false

    private init() {}

    func checkAuthState() async {
        guard let token = await KeychainStore.shared.getToken(), !token.isEmpty else {
            isAuthenticated = false
            return
        }

        do {
            let admin: AdminInfo = try await APIClient.shared.request(.me)
            currentAdmin = admin
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            await KeychainStore.shared.clearAll()
        }
    }

    func login(username: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let request = LoginRequest(username: username, password: password)
        let response: LoginResponse = try await APIClient.shared.request(.login, body: request)

        await KeychainStore.shared.saveToken(response.token)
        currentAdmin = response.admin
        isAuthenticated = true
    }

    func logout() async {
        await KeychainStore.shared.clearAll()
        currentAdmin = nil
        isAuthenticated = false
    }
}
