import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8

    static let cardShadow = Color.black.opacity(0.25)
    static let cardShadowRadius: CGFloat = 12
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppColors.borderColor, lineWidth: 1)
            )
            .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: 4)
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
        .shadow(color: color.opacity(0.3), radius: 8)
    }
}
