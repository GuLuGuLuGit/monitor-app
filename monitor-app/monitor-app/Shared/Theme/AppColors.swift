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
    // MARK: - Backgrounds (Glassmorphism Light)
    static let bgPrimary = Color(hex: "e8f0fc")
    static let bgSecondary = Color(hex: "dfe8f8")
    static let bgCard = Color(.sRGB, red: 255/255, green: 255/255, blue: 255/255, opacity: 0.45)
    static let bgCardHover = Color(.sRGB, red: 255/255, green: 255/255, blue: 255/255, opacity: 0.6)
    static let bgGlass = Color(.sRGB, red: 255/255, green: 255/255, blue: 255/255, opacity: 0.3)

    // MARK: - Borders
    static let borderColor = Color(.sRGB, red: 255/255, green: 255/255, blue: 255/255, opacity: 0.5)
    static let borderGlow = Color(.sRGB, red: 120/255, green: 180/255, blue: 255/255, opacity: 0.5)

    // MARK: - Accent Colors (Neon)
    static let success = Color(hex: "00e676")
    static let warning = Color(hex: "ffab40")
    static let error = Color(hex: "ff5277")
    static let disabled = Color(hex: "b0b8c9")

    static let primary = Color(hex: "5b8def")
    static let cyan = Color(hex: "22d3ee")

    // MARK: - Text (Dark on Light)
    static let textPrimary = Color(hex: "3a4560")
    static let textSecondary = Color(hex: "8595b0")
    static let textTitle = Color(hex: "1e2a3e")

    // MARK: - Gradients
    static let gradientPrimary = LinearGradient(
        colors: [Color(hex: "5b8def"), Color(hex: "22d3ee")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let gradientSuccess = LinearGradient(
        colors: [Color(hex: "00e676"), Color(hex: "22d3ee")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let gradientError = LinearGradient(
        colors: [Color(hex: "ff5277"), Color(hex: "ffa07a")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let gradientBg = LinearGradient(
        colors: [Color(hex: "e8f0fc"), Color(hex: "d6e4f7"), Color(hex: "e0ecff")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
