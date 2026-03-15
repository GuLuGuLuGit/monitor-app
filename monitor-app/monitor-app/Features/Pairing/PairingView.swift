import SwiftUI
import UIKit

struct PairingView: View {
    @State private var pairingCode = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var pairedDeviceInfo: PairingConfirmResponse?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var copiedInstallKey: String?

    private var baseInstallCommand: String {
        let base = AppConfig.baseURL.replacingOccurrences(of: "/api/v1", with: "")
        return "curl -fsSL \(base)/install.sh | bash -s -- --server \(base)"
    }

    private var installCommands: [(key: String, title: String, command: String)] {
        [
            ("macos", "macOS", baseInstallCommand),
            ("linux", "Linux", baseInstallCommand),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gradientBg.ignoresSafeArea()

                if let device = pairedDeviceInfo {
                    successView(device)
                } else {
                    inputView
                }
            }
            .navigationTitle("添加设备")
            .navigationBarTitleDisplayMode(.inline)
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
                    .shadow(color: AppColors.primary.opacity(0.25), radius: 12)

                Text("输入配对码")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textTitle)

                Text("请输入 Agent 终端显示的 6 位配对码")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(installCommands, id: \.key) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.textTitle)
                            Spacer()
                            Button(copiedInstallKey == item.key ? "已复制" : "复制") {
                                UIPasteboard.general.string = item.command
                                copiedInstallKey = item.key
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedInstallKey == item.key { copiedInstallKey = nil }
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.primary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(item.command)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppColors.borderColor, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal)

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
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                    .stroke(
                                        index == pairingCode.count ? AppColors.primary.opacity(0.6) : AppColors.borderColor,
                                        lineWidth: index == pairingCode.count ? 2 : 1
                                    )
                            )
                            .shadow(color: AppTheme.neumorphicShadow.opacity(0.3), radius: 3, x: 2, y: 2)
                    }
                }
                .onTapGesture { isFocused = true }

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
                .shadow(color: pairingCode.count == 6 ? AppColors.primary.opacity(0.3) : .clear, radius: 8)
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
                .shadow(color: AppColors.success.opacity(0.35), radius: 16)

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
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 8)
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
