import SwiftUI

struct PairingView: View {
    @State private var pairingCode = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var pairedDeviceInfo: PairingConfirmResponse?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.bgPrimary.ignoresSafeArea()

                if let device = pairedDeviceInfo {
                    successView(device)
                } else {
                    inputView
                }
            }
            .navigationTitle("添加设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var inputView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.gradientPrimary)

                Text("输入配对码")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textTitle)

                Text("请输入 Agent 终端显示的 6 位配对码")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // 6-character code input
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        let char = index < pairingCode.count
                            ? String(pairingCode[pairingCode.index(pairingCode.startIndex, offsetBy: index)])
                            : ""
                        Text(char)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.textTitle)
                            .frame(width: 44, height: 56)
                            .background(AppColors.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                    .stroke(
                                        index == pairingCode.count ? AppColors.primary : AppColors.borderColor,
                                        lineWidth: index == pairingCode.count ? 2 : 1
                                    )
                            )
                    }
                }
                .onTapGesture { isFocused = true }

                // Hidden text field for actual input
                TextField("", text: $pairingCode)
                    .focused($isFocused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .opacity(0)
                    .frame(width: 1, height: 1)
                    .onChange(of: pairingCode) { _, newValue in
                        pairingCode = String(newValue.uppercased().prefix(6))
                            .filter { $0.isLetter || $0.isNumber }
                        if pairingCode.count == 6 {
                            Task { await submitPairing() }
                        }
                    }
            }

            if let error = errorMessage {
                ErrorBanner(message: error) { errorMessage = nil }
            }

            Button {
                Task { await submitPairing() }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    }
                    Text("确认配对")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    pairingCode.count == 6
                        ? AppColors.gradientPrimary
                        : LinearGradient(colors: [AppColors.disabled], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            }
            .disabled(pairingCode.count != 6 || isSubmitting)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .onAppear { isFocused = true }
    }

    private func successView(_ device: PairingConfirmResponse) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.success)
                .shadow(color: AppColors.success.opacity(0.4), radius: 16)

            Text("配对成功!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textTitle)

            VStack(spacing: 8) {
                Text(device.hostname)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Node ID: \(String(device.nodeId.prefix(12)))...")
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding()
            .cardStyle()

            Button {
                dismiss()
            } label: {
                Text("完成")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.gradientPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    private func submitPairing() async {
        guard pairingCode.count == 6, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            let request = PairingConfirmRequest(pairingCode: pairingCode)
            let response: PairingConfirmResponse = try await APIClient.shared.request(.pairingConfirm, body: request)
            withAnimation {
                pairedDeviceInfo = response
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
            pairingCode = ""
        } catch {
            errorMessage = error.localizedDescription
            pairingCode = ""
        }

        isSubmitting = false
    }
}

struct PairingConfirmRequest: Encodable {
    let pairingCode: String

    enum CodingKeys: String, CodingKey {
        case pairingCode = "pairing_code"
    }
}

struct PairingConfirmResponse: Decodable {
    let deviceId: String
    let nodeId: String
    let hostname: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case nodeId = "node_id"
        case hostname
    }
}
