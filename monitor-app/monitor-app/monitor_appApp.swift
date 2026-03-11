import SwiftUI

@main
struct monitor_appApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .withToast()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { @MainActor in
                    if BiometricAuth.shared.isLocked {
                        _ = await BiometricAuth.shared.authenticate()
                    }
                }
            case .background:
                Task { @MainActor in
                    BiometricAuth.shared.lockApp()
                }
            default:
                break
            }
        }
    }
}
