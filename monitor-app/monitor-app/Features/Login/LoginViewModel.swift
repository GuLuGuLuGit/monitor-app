import Foundation
import Observation

@Observable
@MainActor
final class LoginViewModel {
    var username = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?
    var rememberLogin = true

    var isFormValid: Bool {
        username.count >= 3 && password.count >= 6
    }

    func login() async {
        guard isFormValid else {
            errorMessage = "请输入有效的用户名和密码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await AuthManager.shared.login(username: username, password: password)
            if rememberLogin {
                UserDefaults.standard.set(username, forKey: "saved_username")
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadSavedUsername() {
        if let saved = UserDefaults.standard.string(forKey: "saved_username") {
            username = saved
        }
    }
}
