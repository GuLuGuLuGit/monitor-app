import SwiftUI

struct UsageRing: View {
    let value: Double
    let label: String
    var color: Color = AppColors.primary
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 3)
                    .frame(width: size, height: size)

                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(value))%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
