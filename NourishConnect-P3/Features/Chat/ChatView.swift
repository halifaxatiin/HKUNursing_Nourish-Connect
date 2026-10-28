import SwiftUI
import SwiftData

/// One line in the chat.
struct ChatBubble: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    /// What the user sees and hears.
    let text: String
    /// What is sent to the model instead of `text`, when different (the "tip of the day" button).
    var modelText: String? = nil
    /// True for fixed replies and for the user messages that caused them.
    /// Such messages are never sent to the model, now or later in the conversation.
    let localOnly: Bool
}

/// The companion chat. Order of checks for every message the user sends:
/// 1. Distress words (on the phone). If urgent, open the call screen. Nothing is sent anywhere.
/// 2. Medication or diagnosis question: a fixed reply. Nothing is sent anywhere.
/// 3. Otherwise the message goes to the proxy (DeepSeek through OpenRouter). The reply passes
///    ReplyFilter. If it is blocked, offline, or the proxy is not set up, a fixed reply is shown.
/// The conversation is kept in memory only and is gone when the screen closes.
struct ChatView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var speech: SpeechService
    @StateObject private var recognizer = SpeechRecognizer()
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]

    @State private var bubbles: [ChatBubble] = [
        ChatBubble(role: .assistant, text: Str.chatWelcome, localOnly: true)
    ]
    @State private var input = ""
    @State private var sending = false
    @State private var callReason: CallReason?
    @State private var showSupportOffer = false

    private let client = ChatClient()

    var body: some View {
        VStack(spacing: 0) {
            banner
            messageList
            quickActions
            if recognizer.isListening {
                Text("\(Str.chatListening)\(recognizer.transcript)")
                    .font(theme.font(20))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if recognizer.permissionDenied {
                Text(Str.micDenied)
                    .font(theme.font(16))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
            }
            inputBar
        }
        .navigationTitle(Str.chatTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $callReason) { CallScreenCover(reason: $0) }
        .speaksOnAppear(Str.chatWelcome)
        .onChange(of: recognizer.isListening) { wasListening, isListening in
            if wasListening, !isListening, !recognizer.transcript.isEmpty {
                let spoken = recognizer.transcript
                Task { await send(spoken) }
            }
        }
        .onDisappear {
            recognizer.stop()
        }
    }

    // MARK: Pieces

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
            Text(Str.chatBanner)
                .font(theme.font(18, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.25))
        .accessibilityElement(children: .combine)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(bubbles) { bubble in
                        BubbleRow(bubble: bubble) {
                            speech.speak(bubble.text, rate: theme.speechRate)
                        }
                        .id(bubble.id)
                    }
                    if sending {
                        ProgressView()
                            .controlSize(.large)
                            .padding()
                    }
                    if showSupportOffer {
                        Button {
                            callReason = .distressWords
                        } label: {
                            BigButtonLabel(title: Str.chatSupportButton,
                                           hint: Str.callSomeoneHint,
                                           systemImage: "phone.fill",
                                           emphasis: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .onChange(of: bubbles.count) { _, _ in
                if let last = bubbles.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await send(Str.tipPrompt, display: Str.tipChip, isTip: true) }
            } label: {
                Label(Str.tipChip, systemImage: "lightbulb.fill")
                    .font(theme.font(18, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(sending)

            Button {
                callReason = .helpButton
            } label: {
                Label(Str.help, systemImage: "phone.fill")
                    .font(theme.font(18, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            if recognizer.isAvailable {
                Button {
                    Task {
                        if recognizer.isListening {
                            recognizer.stop()
                        } else {
                            speech.stop()
                            await recognizer.start()
                        }
                    }
                } label: {
                    Image(systemName: recognizer.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 44))
                }
                .accessibilityLabel(Str.micHint)
            }

            TextField(Str.chatPlaceholder, text: $input)
                .font(theme.font(20))
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit { Task { await send(input) } }

            Button {
                Task { await send(input) }
            } label: {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 44))
            }
            .accessibilityLabel(Str.send)
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || sending)
        }
        .padding(12)
    }

    // MARK: Sending

    private enum Outcome {
        case reply(String)
        case blocked
        case limit
        case unavailable
        case offline
    }

    @MainActor
    private func send(_ raw: String, display: String? = nil, isTip: Bool = false) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        input = ""
        showSupportOffer = false

        // 1. Distress words: handled on the phone. Nothing is sent to the network.
        let distress = DistressDetector.evaluate(text)
        if case .urgent(let reason) = distress {
            append(.user, text, localOnly: true)
            append(.assistant, Str.chatUrgentReply, localOnly: true)
            callReason = reason
            return
        }

        // 2. Medication and diagnosis questions: a fixed reply, never the model.
        switch InputGuard.classify(text) {
        case .medication:
            append(.user, text, localOnly: true)
            append(.assistant, Str.chatMedicationReply, localOnly: true)
            return
        case .diagnosis:
            append(.user, text, localOnly: true)
            append(.assistant, Str.chatDiagnosisReply, localOnly: true)
            return
        case .ok:
            break
        }

        // 3. Ordinary message.
        bubbles.append(ChatBubble(role: .user,
                                  text: display ?? text,
                                  modelText: display == nil ? nil : text,
                                  localOnly: false))
        sending = true
        let outcome = await ask()
        sending = false

        switch outcome {
        case .reply(let reply):
            append(.assistant, reply, localOnly: false)
        case .blocked:
            append(.assistant, isTip ? tipFallback() : Str.chatSafeFallback, localOnly: true)
        case .limit:
            append(.assistant, isTip ? tipFallback() : Str.chatLimitReply, localOnly: true)
        case .unavailable:
            append(.assistant, isTip ? tipFallback() : Str.chatUnavailable, localOnly: true)
        case .offline:
            append(.assistant, isTip ? tipFallback() : Str.chatOffline, localOnly: true)
        }

        // Sadness or loneliness: always offer a person to talk to, whatever the model said.
        if distress == .concern {
            showSupportOffer = true
        }
    }

    @MainActor
    private func ask() async -> Outcome {
        guard Config.isChatConfigured else { return .unavailable }
        do {
            let raw = try await client.reply(history: modelHistory(), context: ChatContext.lines(for: today))
            switch ReplyFilter.check(raw) {
            case .ok(let clean): return .reply(clean)
            case .blocked: return .blocked
            }
        } catch let error as ChatClientError {
            switch error {
            case .rateLimited: return .limit
            case .notConfigured: return .unavailable
            case .network, .badReply: return .offline
            }
        } catch {
            return .offline
        }
    }

    /// The turns the model may see: no fixed replies, no messages that triggered them,
    /// and starting with a user turn.
    private func modelHistory() -> [ChatTurn] {
        var turns = bubbles
            .filter { !$0.localOnly }
            .map { ChatTurn(role: $0.role == .user ? .user : .assistant, text: $0.modelText ?? $0.text) }
        while turns.first?.role == .assistant {
            turns.removeFirst()
        }
        return turns
    }

    private var today: DaySummary? {
        WeekSummary.build(
            meals: meals.map { (date: $0.date, rating: $0.rating) },
            moods: moods.map { (date: $0.date, level: $0.level) },
            now: .now,
            days: 1
        ).first
    }

    private func tipFallback() -> String {
        TipFallback.tip(for: today, now: .now)
    }

    private func append(_ role: ChatBubble.Role, _ text: String, localOnly: Bool) {
        bubbles.append(ChatBubble(role: role, text: text, localOnly: localOnly))
        if role == .assistant, theme.speechEnabled {
            speech.speak(text, rate: theme.speechRate)
        }
    }
}

private struct BubbleRow: View {
    @Environment(\.theme) private var theme

    let bubble: ChatBubble
    let onSpeak: () -> Void

    private var isUser: Bool { bubble.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            Text(bubble.text)
                .font(theme.font(22))
                .foregroundStyle(isUser ? theme.onFill : Color.primary)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isUser ? theme.fill() : Color.secondary.opacity(0.18))
                )

            if !isUser {
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 26))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Str.readAloud)
                Spacer(minLength: 20)
            }
        }
    }
}
