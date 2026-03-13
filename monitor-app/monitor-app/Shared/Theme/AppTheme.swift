import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 20
    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 28

    static let neumorphicLight = Color.white.opacity(0.8)
    static let neumorphicShadow = Color(.sRGB, red: 166/255, green: 180/255, blue: 210/255, opacity: 0.35)
    static let cardShadowRadius: CGFloat = 8
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppColors.borderColor, lineWidth: 1)
            )
            .shadow(color: AppTheme.neumorphicShadow, radius: AppTheme.cardShadowRadius, x: 3, y: 3)
            .shadow(color: AppTheme.neumorphicLight, radius: AppTheme.cardShadowRadius, x: -3, y: -3)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    func glowBorder(color: Color = AppColors.borderGlow, radius: CGFloat = AppTheme.cornerRadius) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(color, lineWidth: 1)
        )
        .shadow(color: color.opacity(0.25), radius: 8)
    }

    func glassBg() -> some View {
        background(AppColors.gradientBg.ignoresSafeArea())
    }
}
