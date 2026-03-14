import SwiftUI
import Speech

struct AgentChatView: View {
    let agents: [OpenClawAgent]
    let agentsSummary: String?
    let deviceId: String
    let deviceInternalId: UInt
    let initialAgentId: String?
    let showAgentSelector: Bool

    @State private var selectedAgent: OpenClawAgent?
    @State private var customAgentName = ""
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false
    @State private var isLoadingHistory = false
    @State private var didInitialize = false
    @State private var isRecording = false
    @State private var unreadAgentIds: Set<String> = []
    @State private var messageClient = AgentMessageClient()

    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine: AVAudioEngine?
    @State private var speechChecked = false
    @State private var speechAvailable = false

    @State private var publicKeyCache: String?

    @FocusState private var isInputFocused: Bool
    @FocusState private var isAgentNameFocused: Bool

    init(
        agents: [OpenClawAgent],
        agentsSummary: String?,
        deviceId: String,
        deviceInternalId: UInt,
        initialAgentId: String? = nil,
        showAgentSelector: Bool = true
    ) {
        self.agents = agents
        self.agentsSummary = agentsSummary
        self.deviceId = deviceId
        self.deviceInternalId = deviceInternalId
        self.initialAgentId = initialAgentId
        self.showAgentSelector = showAgentSelector
        if let initialAgentId,
           let initialAgent = agents.first(where: { $0.id == initialAgentId }) {
            self._selectedAgent = State(initialValue: initialAgent)
        } else if agents.count == 1 {
            self._selectedAgent = State(initialValue: agents[0])
        } else {
            self._selectedAgent = State(initialValue: nil)
        }
    }

    private var hasAgents: Bool { !agents.isEmpty }

    private var activeAgent: (id: String, name: String)? {
        if let agent = selectedAgent {
            return (agent.id, agent.name)
        }
        let name = customAgentName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            return (name, name)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppColors.borderColor)

            if hasAgents && showAgentSelector {
                agentSelector
                Divider().background(AppColors.borderColor)
            } else if !hasAgents {
                agentNameInput
                Divider().background(AppColors.borderColor)
            }

            if activeAgent != nil {
                chatContent
            } else {
                placeholder
            }
        }
        .cardStyle()
        .onAppear {
            if !didInitialize {
                didInitialize = true
                if let selectedAgent {
                    selectAgent(selectedAgent)
                }
            }
            Task { await messageClient.connect(deviceId: deviceId) }
        }
        .onDisappear {
            messageClient.disconnect()
        }
        .onChange(of: messageClient.latestEvent) { _, event in
            guard let event else { return }
            handleIncomingEvent(event)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "message.fill")
                .foregroundStyle(AppColors.primary)
            Text("Agent 消息")
                .font(.headline)
                .foregroundStyle(AppColors.textTitle)
            Spacer()
            if hasAgents {
                Text("\(agents.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppColors.primary.opacity(0.1))
                    .clipShape(Capsule())
            } else if let summary = agentsSummary {
                Text(summary)
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding()
    }

    // MARK: - Agent Selector (when agents list available)

    private var agentSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(agents) { agent in
                    let online = isAgentOnline(agent)
                    Button { selectAgent(agent) } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(online ? AppColors.success : AppColors.disabled)
                                .frame(width: 6, height: 6)
                            Text(agent.name)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(online ? "在线" : "离线")
                                .font(.caption2)
                                .foregroundStyle(online ? AppColors.success : AppColors.textSecondary)
                            if unreadAgentIds.contains(agent.id) {
                                Circle()
                                    .fill(AppColors.error)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedAgent?.id == agent.id
                                ? AppColors.primary.opacity(0.15)
                                : Color.clear
                        )
                        .foregroundStyle(
                            selectedAgent?.id == agent.id
                                ? AppColors.primary
                                : AppColors.textSecondary
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                selectedAgent?.id == agent.id
                                    ? AppColors.primary.opacity(0.3)
                                    : AppColors.borderColor,
                                lineWidth: 1
                            )
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Agent Name Input (when agents list unavailable)

    private var agentNameInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.fill.questionmark")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            TextField("输入 Agent 名称 (如 default)", text: $customAgentName)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .focused($isAgentNameFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit {
                    if !customAgentName.trimmingCharacters(in: .whitespaces).isEmpty {
                        let name = customAgentName.trimmingCharacters(in: .whitespaces)
                        unreadAgentIds.remove(name)
                        Task { await loadHistory(agentId: name) }
                    }
                }

            if !customAgentName.isEmpty {
                Button {
                    let name = customAgentName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        messages = []
                        unreadAgentIds.remove(name)
                        Task { await loadHistory(agentId: name) }
                    }
                } label: {
                    Text("连接")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(AppColors.gradientPrimary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if isLoadingHistory {
                            ProgressView()
                                .tint(AppColors.primary)
                                .padding()
                        } else if messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 32))
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                                Text("开始与 \(activeAgent?.name ?? "Agent") 对话")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(.vertical, 32)
                        } else {
                            ForEach(messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            Divider().background(AppColors.borderColor)
            inputBar
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 48) }

            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
                if msg.inputType == .voice && msg.role == .user {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10))
                        Text("语音")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(AppColors.primary.opacity(0.7))
                }

                Text(msg.content)
                    .font(.subheadline)
                    .foregroundStyle(msg.role == .user ? .white : AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        msg.role == .user
                            ? AnyShapeStyle(AppColors.gradientPrimary)
                            : AnyShapeStyle(Color.white.opacity(0.5))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.neumorphicShadow.opacity(0.2), radius: 3, x: 1, y: 1)

                HStack(spacing: 4) {
                    Text(msg.timeString)
                        .font(.system(size: 9))
                    if msg.role == .user {
                        Text(msg.statusLabel)
                            .font(.system(size: 9))
                    }
                }
                .foregroundStyle(AppColors.textSecondary.opacity(0.7))
            }

            if msg.role == .assistant { Spacer(minLength: 48) }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            Button {
                if !speechChecked {
                    checkSpeechAvailability()
                } else if speechAvailable {
                    isRecording ? stopRecording() : startRecording()
                }
            } label: {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isRecording ? AppColors.error : (speechAvailable ? AppColors.primary : AppColors.disabled))
                    .frame(width: 36, height: 36)
                    .background(
                        isRecording
                            ? AppColors.error.opacity(0.12)
                            : AppColors.primary.opacity(0.1)
                    )
                    .clipShape(Circle())
            }
            .disabled(isSending)

            TextField("输入消息...", text: $inputText)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isInputFocused ? AppColors.primary.opacity(0.4) : AppColors.borderColor, lineWidth: 1)
                )
                .onSubmit { sendMessage() }
                .submitLabel(.send)

            Button {
                if isRecording && !inputText.isEmpty {
                    stopRecording()
                    sendMessage(inputType: .voice)
                } else {
                    sendMessage()
                }
            } label: {
                Group {
                    if isSending {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                    }
                }
                .foregroundStyle(
                    inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
                        ? AppColors.disabled
                        : AppColors.primary
                )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: hasAgents ? "hand.point.up.left.fill" : "person.fill.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
            Text(hasAgents ? "选择一个 Agent 开始对话" : "输入 Agent 名称开始对话")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func selectAgent(_ agent: OpenClawAgent) {
        let isSameAgent = selectedAgent?.id == agent.id
        selectedAgent = agent
        customAgentName = ""
        inputText = ""
        unreadAgentIds.remove(agent.id)
        if !isSameAgent || messages.isEmpty {
            Task { await loadHistory(agentId: agent.id) }
        }
    }

    private func loadHistory(agentId: String) async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let result: CommandListResponse = try await APIClient.shared.request(
                .commands,
                queryItems: [
                    URLQueryItem(name: "device_id", value: deviceId),
                    URLQueryItem(name: "command_type", value: "openclaw_message"),
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "page_size", value: "50"),
                ]
            )

            var msgs: [ChatMessage] = []
            for cmd in result.commands.reversed() {
                let params = cmd.commandParams
                let cmdAgentId = (params?["agent_id"]?.value as? String) ?? ""
                guard cmdAgentId == agentId else { continue }

                let text = (params?["message"]?.value as? String) ?? ""
                let inputTypeStr = (params?["input_type"]?.value as? String) ?? "text"

                msgs.append(ChatMessage(
                    id: "user-\(cmd.id)",
                    role: .user,
                    content: text,
                    time: cmd.createdAt,
                    status: cmd.status,
                    inputType: inputTypeStr == "voice" ? .voice : .text
                ))

                if !cmd.result.isEmpty {
                    msgs.append(ChatMessage(
                        id: "reply-\(cmd.id)",
                        role: .assistant,
                        content: cmd.result,
                        time: cmd.executedAt ?? cmd.updatedAt,
                        status: cmd.status,
                        inputType: .text
                    ))
                }
            }
            messages = msgs
        } catch {
            // Non-critical
        }
    }

    private func handleIncomingEvent(_ event: AgentMessageEvent) {
        guard event.deviceId == deviceId else { return }
        let agentId = event.agentId.trimmingCharacters(in: .whitespaces)
        guard !agentId.isEmpty else { return }

        let isActive = activeAgent?.id == agentId
        if isActive {
            unreadAgentIds.remove(agentId)
        }
        if event.role == "assistant" {
            let msg = ChatMessage(
                id: "reply-\(event.commandId)",
                role: .assistant,
                content: event.content,
                time: event.createdAt,
                status: event.status,
                inputType: .text
            )
            if isActive {
                appendOrReplace(msg)
                updateUserStatus(commandId: event.commandId, status: event.status)
            } else {
                unreadAgentIds.insert(agentId)
            }
        } else {
            let inputType: ChatMessage.InputType = (event.inputType == "voice") ? .voice : .text
            let msg = ChatMessage(
                id: "user-\(event.commandId)",
                role: .user,
                content: event.content,
                time: event.createdAt,
                status: event.status,
                inputType: inputType
            )
            if isActive {
                if let idx = messages.firstIndex(where: { $0.id.hasPrefix("temp-") && $0.role == .user && $0.content == event.content }) {
                    messages[idx] = msg
                } else {
                    appendOrReplace(msg)
                }
            } else {
                unreadAgentIds.insert(agentId)
            }
        }
    }

    private func appendOrReplace(_ msg: ChatMessage) {
        if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
            messages[idx] = msg
        } else {
            messages.append(msg)
        }
    }

    private func updateUserStatus(commandId: Int64, status: Int8) {
        let userId = "user-\(commandId)"
        guard let idx = messages.firstIndex(where: { $0.id == userId }) else { return }
        let old = messages[idx]
        messages[idx] = ChatMessage(
            id: old.id,
            role: old.role,
            content: old.content,
            time: old.time,
            status: status,
            inputType: old.inputType
        )
    }

    private func isAgentOnline(_ agent: OpenClawAgent) -> Bool {
        guard let active = agent.active?.trimmingCharacters(in: .whitespacesAndNewlines),
              !active.isEmpty else { return false }
        let lower = active.lowercased()
        if ["true", "yes", "online", "active", "now"].contains(lower) {
            return true
        }
        if let age = parseActiveAge(lower) {
            return age <= 3600 // 1 hour
        }
        return false
    }

    private func parseActiveAge(_ value: String) -> TimeInterval? {
        let parts = value.split(separator: " ")
        guard let token = parts.first else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let unit = trimmed.last else { return nil }
        let numberStr = trimmed.dropLast()
        guard let num = Double(numberStr) else { return nil }

        switch unit {
        case "s": return num
        case "m": return num * 60
        case "h": return num * 3600
        case "d": return num * 86400
        case "w": return num * 604800
        default: return nil
        }
    }

    private func sendMessage(inputType: ChatMessage.InputType = .text) {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let agent = activeAgent else { return }

        let tempMsg = ChatMessage(
            id: "temp-\(Date().timeIntervalSince1970)",
            role: .user,
            content: text,
            time: Date(),
            status: 0,
            inputType: inputType
        )
        messages.append(tempMsg)
        inputText = ""
        isSending = true

        Task {
            defer { isSending = false }
            do {
                let params: [String: Any] = [
                    "agent_id": agent.id,
                    "agent_name": agent.name,
                    "message": text,
                    "input_type": inputType == .voice ? "voice" : "text",
                ]

                let publicKey = try await fetchPublicKey()
                let commandData = CommandPayload(commandType: "openclaw_message", params: params)
                let envelopeJson = try E2ECrypto.sealJSON(commandData, publicKeyPEM: publicKey)

                let request = CreateEncryptedCommandRequest(
                    deviceId: deviceId,
                    commandType: "openclaw_message",
                    commandParams: params.mapValues { AnyCodable($0) },
                    encryptedPayload: envelopeJson,
                    isEncrypted: true
                )
                let cmd: AgentCommand = try await APIClient.shared.request(.createCommand, body: request)
                ToastManager.shared.success("消息已发送")

                await MainActor.run {
                    if let idx = messages.firstIndex(where: { $0.id == tempMsg.id }) {
                        messages[idx] = ChatMessage(
                            id: "user-\(cmd.id)",
                            role: .user,
                            content: text,
                            time: cmd.createdAt,
                            status: cmd.status,
                            inputType: inputType
                        )
                    }
                }

                if !messageClient.isConnected {
                    try? await Task.sleep(for: .seconds(2))
                    await loadHistory(agentId: agent.id)
                }
            } catch {
                ToastManager.shared.error("发送失败: \(error.localizedDescription)")
            }
        }
    }

    private func fetchPublicKey() async throws -> String {
        if let cached = publicKeyCache { return cached }
        let response: PublicKeyResponse = try await APIClient.shared.request(.devicePublicKey(id: deviceInternalId))
        publicKeyCache = response.publicKey
        return response.publicKey
    }

    // MARK: - Speech

    private func checkSpeechAvailability() {
        speechChecked = true
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                speechAvailable = (status == .authorized)
                if speechAvailable {
                    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
                    audioEngine = AVAudioEngine()
                }
            }
        }
    }

    private func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable,
              let engine = audioEngine else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                Task { @MainActor in
                    inputText = result.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    stopRecording()
                }
            }
        }

        engine.prepare()
        try? engine.start()
        isRecording = true
    }

    private func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}

// MARK: - ChatMessage Model

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    enum InputType { case text, voice }

    let id: String
    let role: Role
    let content: String
    let time: Date
    let status: Int8
    let inputType: InputType

    var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: time)
    }

    var statusLabel: String {
        switch status {
        case 0: "· 发送中"
        case 1: "· 处理中"
        case 2: ""
        case 3: "· 失败"
        default: ""
        }
    }
}
