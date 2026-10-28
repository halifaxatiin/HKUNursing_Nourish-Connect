import SwiftUI
import SwiftData

/// Three-tap mood check. After the tap the app answers kindly, and if the recent pattern calls for it
/// (see MoodRules) it opens the call screen. Everything stays on the phone.
struct MoodCheckView: View {
    private enum Phase: Equatable {
        case choosing
        case answered(level: Int, action: MoodAction)
    }

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var speech: SpeechService
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]

    @State private var phase: Phase = .choosing
    @State private var callReason: CallReason?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch phase {
                case .choosing:
                    choices
                case .answered(let level, let action):
                    answer(level: level, action: action)
                }
            }
            .padding(20)
        }
        .navigationTitle(Str.moodCheckTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $callReason) { CallScreenCover(reason: $0) }
        .speaksOnAppear(Str.moodCheckSpoken)
    }

    // MARK: Choosing

    @ViewBuilder
    private var choices: some View {
        Text(Str.moodCheckSpoken)
            .font(theme.font(28, weight: .bold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

        Button { choose(0) } label: {
            BigButtonLabel(title: Str.moodOkay, hint: Str.moodOkayHint, systemImage: "sun.max.fill")
        }
        .buttonStyle(.plain)

        Button { choose(1) } label: {
            BigButtonLabel(title: Str.moodLonely, hint: Str.moodLonelyHint, systemImage: "cloud.fill")
        }
        .buttonStyle(.plain)

        Button { choose(2) } label: {
            BigButtonLabel(title: Str.moodNotWell, hint: Str.moodNotWellHint, systemImage: "cloud.rain.fill")
        }
        .buttonStyle(.plain)

        ReadAloudButton(text: Str.moodCheckSpoken)
    }

    // MARK: Answer

    @ViewBuilder
    private func answer(level: Int, action: MoodAction) -> some View {
        let text = answerText(level: level, action: action)

        Text(text)
            .font(theme.font(26, weight: .semibold))
            .multilineTextAlignment(.center)
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20).stroke(theme.fill(), lineWidth: 3))

        if action != .none {
            Button {
                callReason = action == .alert ? .moodPattern : .moodNotWell
            } label: {
                BigButtonLabel(title: Str.callSomeone, hint: Str.callSomeoneHint, systemImage: "phone.fill", emphasis: true)
            }
            .buttonStyle(.plain)
        }

        if level >= 1 {
            NavigationLink(value: MoodRoute.breathing) {
                BigButtonLabel(title: Str.breathing, hint: Str.breathingHint, systemImage: "wind")
            }
            .buttonStyle(.plain)

            NavigationLink(value: MoodRoute.chat) {
                BigButtonLabel(title: Str.chat, hint: Str.chatHint, systemImage: "bubble.left.and.bubble.right.fill")
            }
            .buttonStyle(.plain)
        }

        ReadAloudButton(text: text)

        Button {
            dismiss()
        } label: {
            Label(Str.done, systemImage: "checkmark")
                .font(theme.font(22, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)

        Text(Str.moodSaved)
            .font(theme.font(16))
            .foregroundStyle(.secondary)
    }

    private func answerText(level: Int, action: MoodAction) -> String {
        switch (level, action) {
        case (_, .alert): return Str.moodAnswerPattern
        case (2, _): return Str.moodAnswerNotWell
        case (1, _): return Str.moodAnswerLonely
        default: return Str.moodAnswerOkay
        }
    }

    // MARK: Logic

    private func choose(_ level: Int) {
        let now = Date.now
        context.insert(MoodEntry(date: now, level: level, source: "tap"))

        // The new entry is not in `moods` yet, so add it by hand.
        var entries = moods.map { (date: $0.date, level: $0.level) }
        entries.append((date: now, level: level))
        let action = MoodRules.action(entries: entries, now: now)

        phase = .answered(level: level, action: action)
        let text = answerText(level: level, action: action)
        if theme.speechEnabled {
            speech.speak(text, rate: theme.speechRate)
        }
        if action == .alert {
            callReason = .moodPattern
        }
    }
}
