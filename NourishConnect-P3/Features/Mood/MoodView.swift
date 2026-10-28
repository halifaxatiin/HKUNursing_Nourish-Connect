import SwiftUI

enum MoodRoute: Hashable {
    case check
    case breathing
    case chat
    case week
}

/// Mood hub: the mood check, breathing, chat and the weekly view.
struct MoodView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NavigationLink(value: MoodRoute.check) {
                    BigButtonLabel(title: Str.moodCheck, hint: Str.moodCheckHint, systemImage: "heart.fill")
                }
                .buttonStyle(.plain)

                NavigationLink(value: MoodRoute.breathing) {
                    BigButtonLabel(title: Str.breathing, hint: Str.breathingHint, systemImage: "wind")
                }
                .buttonStyle(.plain)

                NavigationLink(value: MoodRoute.chat) {
                    BigButtonLabel(title: Str.chat, hint: Str.chatHint, systemImage: "bubble.left.and.bubble.right.fill")
                }
                .buttonStyle(.plain)

                NavigationLink(value: MoodRoute.week) {
                    BigButtonLabel(title: Str.week, hint: Str.weekHint, systemImage: "calendar")
                }
                .buttonStyle(.plain)

                ReadAloudButton(text: Str.moodSpoken)
            }
            .padding(20)
        }
        .navigationTitle(Str.mood)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MoodRoute.self) { route in
            switch route {
            case .check: MoodCheckView()
            case .breathing: BreathingView()
            case .chat: ChatView()
            case .week: WeekView()
            }
        }
        .speaksOnAppear(Str.moodSpoken)
    }
}
