import SwiftUI

struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }

    var body: some View {
        ZStack {
            AppColors.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo & Title
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(AppColors.gradientPrimary)
                            .shadow(color: AppColors.primary.opacity(0.4), radius: 20)

                        Text("OpenClaw")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textTitle)

                        Text("远程管理平台")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    // Form
                    VStack(spacing: 20) {
                        // Error banner
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error) {
                                viewModel.errorMessage = nil
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Username
                        VStack(alignment: .leading, spacing: 6) {
                            Text("用户名")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(AppColors.textSecondary)
                                    .frame(width: 20)

                                TextField("", text: $viewModel.username)
                                    .textContentType(.username)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .focused($focusedField, equals: .username)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                            }
                            .padding()
                            .background(AppColors.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                    .stroke(
                                        focusedField == .username ? AppColors.primary : AppColors.borderColor,
                                        lineWidth: 1
                                    )
                            )
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("密码")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(AppColors.textSecondary)
                                    .frame(width: 20)

                                SecureField("", text: $viewModel.password)
                                    .textContentType(.password)
                                    .focused($focusedField, equals: .password)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .submitLabel(.go)
                                    .onSubmit { Task { await viewModel.login() } }
                            }
                            .padding()
                            .background(AppColors.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                    .stroke(
                                        focusedField == .password ? AppColors.primary : AppColors.borderColor,
                                        lineWidth: 1
                                    )
                            )
                        }

                        // Remember me
                        Toggle(isOn: $viewModel.rememberLogin) {
                            Text("记住登录")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .tint(AppColors.primary)

                        // Login button
                        Button {
                            Task { await viewModel.login() }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                }
                                Text("登录")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                viewModel.isFormValid
                                    ? AppColors.gradientPrimary
                                    : LinearGradient(colors: [AppColors.disabled], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                            .shadow(color: viewModel.isFormValid ? AppColors.primary.opacity(0.4) : .clear, radius: 12)
                        }
                        .disabled(!viewModel.isFormValid || viewModel.isLoading)
                    }
                    .padding(24)
                    .cardStyle()

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage != nil)
        .onAppear {
            viewModel.loadSavedUsername()
        }
    }
}
