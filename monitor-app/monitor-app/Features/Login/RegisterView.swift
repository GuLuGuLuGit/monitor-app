import SwiftUI
import Observation

@Observable
@MainActor
final class RegisterViewModel {
    var email = ""
    var code = ""
    var username = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var isSendingCode = false
    var errorMessage: String?
    var countdown = 0

    private var timer: Timer?

    var isFormValid: Bool {
        !email.isEmpty
        && !code.isEmpty
        && username.count >= 3 && username.count <= 50
        && password.count >= 6
        && password == confirmPassword
    }

    var canSendCode: Bool {
        !email.isEmpty && countdown == 0 && !isSendingCode
    }

    func sendCode() async {
        isSendingCode = true
        errorMessage = nil

        do {
            let _: MessageResponse = try await APIClient.shared.request(
                .sendCode,
                body: SendCodeRequest(email: email, type: "register")
            )
            startCountdown()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSendingCode = false
    }

    func register() async -> Bool {
        guard isFormValid else {
            errorMessage = "请完整填写所有字段"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: LoginResponse = try await APIClient.shared.request(
                .register,
                body: RegisterRequest(
                    username: username,
                    email: email,
                    password: password,
                    code: code
                )
            )
            await KeychainStore.shared.saveToken(response.token)
            AuthManager.shared.setAuthenticated(admin: response.admin)
            isLoading = false
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        return false
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self else { t.invalidate(); return }
                self.countdown -= 1
                if self.countdown <= 0 {
                    self.countdown = 0
                    t.invalidate()
                }
            }
        }
    }
}

struct RegisterView: View {
    @State private var viewModel = RegisterViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, code, username, password, confirmPassword
    }

    var body: some View {
        ZStack {
            AppColors.gradientBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 20)

                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(AppColors.gradientPrimary)
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 16)

                        Text("注册账号")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textTitle)

                        Text("创建你的 OpenClaw 账号")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    VStack(spacing: 20) {
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error) {
                                viewModel.errorMessage = nil
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        inputField(
                            label: "邮箱",
                            icon: "envelope.fill",
                            field: .email
                        ) {
                            TextField("", text: $viewModel.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .email)
                                .foregroundStyle(AppColors.textPrimary)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .code }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("验证码")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)

                            HStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "number.square.fill")
                                        .foregroundStyle(AppColors.textSecondary)
                                        .frame(width: 20)

                                    TextField("", text: $viewModel.code)
                                        .keyboardType(.numberPad)
                                        .focused($focusedField, equals: .code)
                                        .foregroundStyle(AppColors.textPrimary)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                        .stroke(
                                            focusedField == .code ? AppColors.primary.opacity(0.6) : AppColors.borderColor,
                                            lineWidth: 1
                                        )
                                )

                                Button {
                                    Task { await viewModel.sendCode() }
                                } label: {
                                    Group {
                                        if viewModel.isSendingCode {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(.white)
                                                .scaleEffect(0.7)
                                        } else if viewModel.countdown > 0 {
                                            Text("\(viewModel.countdown)s")
                                                .fontWeight(.medium)
                                        } else {
                                            Text("发送验证码")
                                                .fontWeight(.medium)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 90, height: 48)
                                    .background(
                                        viewModel.canSendCode
                                            ? AppColors.gradientPrimary
                                            : LinearGradient(colors: [AppColors.disabled], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                                }
                                .disabled(!viewModel.canSendCode)
                            }
                        }

                        inputField(
                            label: "用户名 (3-50 个字符)",
                            icon: "person.fill",
                            field: .username
                        ) {
                            TextField("", text: $viewModel.username)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .username)
                                .foregroundStyle(AppColors.textPrimary)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }

                        inputField(
                            label: "密码 (至少 6 位)",
                            icon: "lock.fill",
                            field: .password
                        ) {
                            SecureField("", text: $viewModel.password)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .password)
                                .foregroundStyle(AppColors.textPrimary)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .confirmPassword }
                        }

                        inputField(
                            label: "确认密码",
                            icon: "lock.rotation",
                            field: .confirmPassword
                        ) {
                            SecureField("", text: $viewModel.confirmPassword)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .confirmPassword)
                                .foregroundStyle(AppColors.textPrimary)
                                .submitLabel(.go)
                                .onSubmit { Task { if await viewModel.register() { dismiss() } } }
                        }

                        Button {
                            Task { if await viewModel.register() { dismiss() } }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                }
                                Text("注册")
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
                            .shadow(color: viewModel.isFormValid ? AppColors.primary.opacity(0.3) : .clear, radius: 10)
                        }
                        .disabled(!viewModel.isFormValid || viewModel.isLoading)

                        Button {
                            dismiss()
                        } label: {
                            Text("已有账号？登录")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                    .padding(24)
                    .cardStyle()

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage != nil)
    }

    private func inputField<Content: View>(
        label: String,
        icon: String,
        field: Field,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 20)

                content()
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .stroke(
                        focusedField == field ? AppColors.primary.opacity(0.6) : AppColors.borderColor,
                        lineWidth: 1
                    )
            )
        }
    }
}
