import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = AppColors.primary
    var gradient: LinearGradient? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    gradient ?? LinearGradient(colors: [color, color], startPoint: .leading, endPoint: .trailing)
                )

            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
