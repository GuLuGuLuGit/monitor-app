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
    @State private var liveOnlineAgentIds: Set<String> = []
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

    private struct MarkAgentReadBody: Encodable {
        let agentId: String

        enum CodingKeys: String, CodingKey {
            case agentId = "agent_id"
        }
    }

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
        ZStack {
            AppColors.gradientBg.ignoresSafeArea()

            VStack(spacing: 16) {
                if hasAgents && showAgentSelector {
                    agentRoster
                } else if !hasAgents {
                    manualAgentCard
                }

                if activeAgent != nil {
                    chatWorkspace
                } else {
                    placeholderCard
                }
            }
            .padding()
        }
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

    private var agentRoster: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agents")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
                Spacer()
                Text("\(agents.filter(isAgentOnline).count) 在线 / \(agents.count) 总数")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(agents) { agent in
                    let online = isAgentOnline(agent)
                    Button { selectAgent(agent) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(online ? AppColors.success : AppColors.disabled)
                                    .frame(width: 8, height: 8)
                                Spacer()
                                if unreadAgentIds.contains(agent.id) {
                                    Circle()
                                        .fill(AppColors.error)
                                        .frame(width: 8, height: 8)
                                }
                            }

                            Text(agent.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(selectedAgent?.id == agent.id ? AppColors.primary : AppColors.textPrimary)
                                .lineLimit(1)
                            Text(agent.sessionModel ?? agent.id)
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                            if let sessionTokens = agent.sessionTokens, !sessionTokens.isEmpty {
                                Text(sessionTokens)
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                            }
                            HStack(spacing: 6) {
                                statusCapsule(text: online ? "在线" : "离线", color: online ? AppColors.success : AppColors.disabled)
                                if unreadAgentIds.contains(agent.id) {
                                    statusCapsule(text: "未读", color: AppColors.error)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(selectedAgent?.id == agent.id ? AppColors.primary.opacity(0.12) : Color.white.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                .stroke(selectedAgent?.id == agent.id ? AppColors.primary.opacity(0.3) : AppColors.borderColor, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var manualAgentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agent")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
                Spacer()
                if let agentsSummary, !agentsSummary.isEmpty {
                    Text(agentsSummary)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            HStack(spacing: 10) {
                TextField("输入 Agent 名称，例如 default", text: $customAgentName)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .focused($isAgentNameFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.borderColor, lineWidth: 1)
                    )
                    .submitLabel(.done)
                    .onSubmit {
                        handleConnectCustomAgent()
                    }

                Button("连接") {
                    handleConnectCustomAgent()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.gradientPrimary)
                .clipShape(Capsule())
                .disabled(customAgentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var chatWorkspace: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider().background(AppColors.borderColor)
            chatScrollArea
            Divider().background(AppColors.borderColor)
            inputBar
        }
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .top)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppColors.borderColor, lineWidth: 1)
        )
        .shadow(color: AppTheme.neumorphicShadow, radius: AppTheme.cardShadowRadius, x: 3, y: 3)
        .shadow(color: AppTheme.neumorphicLight, radius: AppTheme.cardShadowRadius, x: -3, y: -3)
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            if let activeAgent,
               let current = agents.first(where: { $0.id == activeAgent.id }) {
                Circle()
                    .fill(isAgentOnline(current) ? AppColors.success : AppColors.disabled)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activeAgent?.name ?? "Agent")
                    .font(.headline)
                    .foregroundStyle(AppColors.textTitle)
            }
            Spacer()
            if isLoadingHistory {
                ProgressView()
                    .tint(AppColors.primary)
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var chatScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if isLoadingHistory {
                        ProgressView()
                            .tint(AppColors.primary)
                            .padding()
                    } else if messages.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 30))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.45))
                            Text("开始与 \(activeAgent?.name ?? "Agent") 对话")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .background(Color.white.opacity(0.18))
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 56) }

            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(msg.role == .user ? "我" : (activeAgent?.name ?? "Agent"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textSecondary)
                    if msg.role == .user, !msg.statusLabel.isEmpty {
                        statusCapsule(
                            text: msg.statusLabel,
                            color: msg.status == 3 ? AppColors.error : AppColors.warning
                        )
                    }
                }

                if msg.inputType == .voice && msg.role == .user {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10))
                        Text("语音")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(AppColors.primary.opacity(0.8))
                }

                Text(msg.content)
                    .font(.subheadline)
                    .foregroundStyle(msg.role == .user ? .white : AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        msg.role == .user
                            ? AnyShapeStyle(AppColors.gradientPrimary)
                            : AnyShapeStyle(Color.white.opacity(0.72))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(msg.role == .user ? Color.clear : AppColors.borderColor, lineWidth: 1)
                    )

                HStack(spacing: 4) {
                    Text(msg.timeString)
                        .font(.system(size: 10))
                }
                .foregroundStyle(AppColors.textSecondary.opacity(0.8))
            }

            if msg.role == .assistant { Spacer(minLength: 56) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
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
                    .frame(width: 40, height: 40)
                    .background(isRecording ? AppColors.error.opacity(0.12) : AppColors.primary.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(isSending)

            TextField("输入消息...", text: $inputText)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.4))
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
                        Label("发送", systemImage: "arrow.up")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
                        ? AnyShapeStyle(AppColors.disabled.opacity(0.7))
                        : AnyShapeStyle(AppColors.gradientPrimary)
                )
                .clipShape(Capsule())
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var placeholderCard: some View {
        VStack(spacing: 12) {
            Image(systemName: hasAgents ? "hand.point.up.left.fill" : "person.fill.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
            Text(hasAgents ? "先从上方名录选择一个 Agent" : "输入 Agent 名称开始对话")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .background(Color.white.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppColors.borderColor, lineWidth: 1)
        )
    }

    private func handleConnectCustomAgent() {
        let name = customAgentName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        messages = []
        unreadAgentIds.remove(name)
        Task { await markAgentRead(name) }
        Task { await loadHistory(agentId: name) }
    }

    private func statusCapsule(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func selectAgent(_ agent: OpenClawAgent) {
        let isSameAgent = selectedAgent?.id == agent.id
        selectedAgent = agent
        customAgentName = ""
        inputText = ""
        unreadAgentIds.remove(agent.id)
        Task { await markAgentRead(agent.id) }
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
            await markAgentRead(agentId)
            if let latestActivity = msgs.map(\.time).max(), Date().timeIntervalSince(latestActivity) <= 900 {
                liveOnlineAgentIds.insert(agentId)
            }
        } catch {
            // Non-critical
        }
    }

    private func handleIncomingEvent(_ event: AgentMessageEvent) {
        guard event.deviceId == deviceId else { return }
        let agentId = event.agentId.trimmingCharacters(in: .whitespaces)
        guard !agentId.isEmpty else { return }

        let isActive = activeAgent?.id == agentId
        liveOnlineAgentIds.insert(agentId)
        if isActive {
            unreadAgentIds.remove(agentId)
            Task { await markAgentRead(agentId) }
        }
        if event.role == "assistant" {
            let resolvedStatus: Int8 = event.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? event.status : 2
            let msg = ChatMessage(
                id: "reply-\(event.commandId)",
                role: .assistant,
                content: event.content,
                time: event.createdAt,
                status: resolvedStatus,
                inputType: .text
            )
            if isActive {
                appendOrReplace(msg)
                updateUserStatus(commandId: event.commandId, status: resolvedStatus)
                Task { await markAgentRead(agentId) }
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
                Task { await markAgentRead(agentId) }
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
        agent.isLikelyOnline(optimistic: liveOnlineAgentIds.contains(agent.id))
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
                liveOnlineAgentIds.insert(agent.id)
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

                Task {
                    await syncCommandResult(commandId: cmd.id)
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

    private func markAgentRead(_ agentId: String) async {
        let trimmed = agentId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let body = MarkAgentReadBody(agentId: trimmed)
            try await APIClient.shared.requestVoid(.deviceAgentRead(id: deviceInternalId), body: body)
            AgentUnreadStore.notifyDidChange()
        } catch {
            // Keep UI responsive; backend count will refresh on next successful sync.
        }
    }

    private func syncCommandResult(commandId: Int64) async {
        for _ in 0..<12 {
            do {
                let cmd: AgentCommand = try await APIClient.shared.request(.command(id: commandId))
                if cmd.status == AgentCommand.Status.pending.rawValue || cmd.status == AgentCommand.Status.running.rawValue {
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }

                let finalStatus: Int8 = cmd.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? cmd.status : 2
                await MainActor.run {
                    updateUserStatus(commandId: commandId, status: finalStatus)
                    let replyText = cmd.result.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !replyText.isEmpty {
                        appendOrReplace(ChatMessage(
                            id: "reply-\(commandId)",
                            role: .assistant,
                            content: replyText,
                            time: cmd.executedAt ?? cmd.updatedAt,
                            status: 2,
                            inputType: .text
                        ))
                    }
                }
                return
            } catch {
                return
            }
        }
    }

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
        case 0: return "发送中"
        case 1: return "处理中"
        case 2: return ""
        case 3: return "失败"
        default: return ""
        }
    }
}
