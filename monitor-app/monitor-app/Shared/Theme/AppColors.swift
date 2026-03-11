import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum AppColors {
    static let bgPrimary = Color(hex: "060a1a")
    static let bgCard = Color(.sRGB, red: 16/255, green: 23/255, blue: 42/255, opacity: 0.85)
    static let bgCardHover = Color(.sRGB, red: 22/255, green: 32/255, blue: 56/255, opacity: 0.95)

    static let borderColor = Color(.sRGB, red: 56/255, green: 96/255, blue: 176/255, opacity: 0.2)
    static let borderGlow = Color(.sRGB, red: 56/255, green: 136/255, blue: 255/255, opacity: 0.35)

    static let success = Color(hex: "00e5a0")
    static let warning = Color(hex: "ffb340")
    static let error = Color(hex: "ff4d6a")
    static let disabled = Color(hex: "5a5e70")

    static let primary = Color(hex: "3b82f6")
    static let cyan = Color(hex: "22d3ee")

    static let textPrimary = Color(hex: "e2e8f0")
    static let textSecondary = Color(hex: "7a8ba8")
    static let textTitle = Color(hex: "f1f5f9")

    static let gradientPrimary = LinearGradient(
        colors: [Color(hex: "3b82f6"), Color(hex: "22d3ee")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let gradientSuccess = LinearGradient(
        colors: [Color(hex: "00e5a0"), Color(hex: "22d3ee")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let gradientError = LinearGradient(
        colors: [Color(hex: "ff4d6a"), Color(hex: "ff8a65")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
