import Foundation
import LocalAuthentication
import Observation

@Observable
@MainActor
final class BiometricAuth {
    static let shared = BiometricAuth()

    private(set) var isAvailable = false
    private(set) var biometricType: LABiometryType = .none
    private(set) var isLocked = false

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometric_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometric_enabled") }
    }

    private init() {
        checkAvailability()
    }

    func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        @unknown default: "生物识别"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        @unknown default: "lock.shield"
        }
    }

    func lockApp() {
        guard isEnabled, isAvailable else { return }
        isLocked = true
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "使用密码"
        context.localizedCancelTitle = "取消"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "解锁灵控"
            )
            if success {
                isLocked = false
            }
            return success
        } catch {
            return false
        }
    }
}
