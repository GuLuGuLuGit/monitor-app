import SwiftUI

extension Color {
    static func deviceStatusColor(_ status: Int8) -> Color {
        switch status {
        case 1:  AppColors.success
        case 0:  AppColors.error
        case -1: AppColors.disabled
        default: AppColors.textSecondary
        }
    }

    static func commandStatusColor(_ status: Int8) -> Color {
        switch status {
        case 0: AppColors.textSecondary
        case 1: AppColors.primary
        case 2: AppColors.success
        case 3: AppColors.error
        case 4: AppColors.warning
        default: AppColors.textSecondary
        }
    }
}
