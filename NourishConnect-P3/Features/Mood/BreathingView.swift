import SwiftUI
import SwiftData

/// A guided breathing exercise of two or three minutes: a circle that grows and shrinks, and a
/// Cantonese voice saying "breathe in" and "breathe out". Only completion is saved, not any health data.
struct BreathingView: View {
    private enum Stage: Equatable {
        case idle
        case running
        case finished
    }

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var speech: SpeechService

    @State private var stage: Stage = .idle
    @State private var cue = ""
    @State private var scale: CGFloat = 0.55
    @State private var elapsed = 0
    @State private var total = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                switch stage {
                case .idle: idle
                case .running: running
                case .finished: finished
                }
            }
            .padding(20)
        }
        .navigationTitle(Str.breathingTitle)
        .navigationBarTitleDisplayMode(.inline)
        .speaksOnAppear(Str.breathingSpoken)
        .onDisappear(perform: leave)
    }

    // MARK: Stages

    @ViewBuilder
    private var idle: some View {
        Text(Str.breathingSpoken)
            .font(theme.font(26, weight: .semibold))
            .multilineTextAlignment(.center)

        Button { start(seconds: 120) } label: {
            BigButtonLabel(title: Str.twoMinutes, hint: Str.minutesHint, systemImage: "timer")
        }
        .buttonStyle(.plain)

        Button { start(seconds: 180) } label: {
            BigButtonLabel(title: Str.threeMinutes, hint: Str.minutesHint, systemImage: "timer")
        }
        .buttonStyle(.plain)

        ReadAloudButton(text: Str.breathingSpoken)
    }

    @ViewBuilder
    private var running: some View {
        ZStack {
            Circle()
                .fill(theme.fill().opacity(0.25))
                .overlay(Circle().stroke(theme.fill(), lineWidth: 6))
                .frame(width: 260, height: 260)
                .scaleEffect(scale)
        }
        .frame(height: 280)
        .accessibilityHidden(true)

        Text(cue)
            .font(theme.font(44, weight: .bold))
            .frame(minHeight: 60)
            .accessibilityLabel(cue)

        Text(Str.secondsLeft(max(0, total - elapsed)))
            .font(theme.font(22))
            .foregroundStyle(.secondary)

        Button {
            stopEarly()
        } label: {
            Label(Str.stop, systemImage: "stop.fill")
                .font(theme.font(24, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder
    private var finished: some View {
        Text(Str.breathingDone)
            .font(theme.font(30, weight: .bold))
            .multilineTextAlignment(.center)
            .padding(.top, 24)

        Button {
            dismiss()
        } label: {
            Label(Str.done, systemImage: "checkmark")
                .font(theme.font(24, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(theme.fill())
        .foregroundStyle(theme.onFill)
    }

    // MARK: Logic

    private func start(seconds: Int) {
        task?.cancel()
        let steps = BreathingPlan.gentle.steps(totalSeconds: seconds)
        total = steps.map { $0.seconds }.reduce(0, +)
        elapsed = 0
        scale = 0.55
        cue = ""
        stage = .running
        UIApplication.shared.isIdleTimerDisabled = true
        task = Task { await run(steps) }
    }

    @MainActor
    private func run(_ steps: [BreathingStep]) async {
        say(Str.breathingIntro)
        try? await Task.sleep(for: .seconds(6))

        for step in steps {
            if Task.isCancelled { return }
            let inhale = step.phase == .inhale
            cue = inhale ? Str.breatheIn : Str.breatheOut
            say(cue)
            withAnimation(.easeInOut(duration: Double(step.seconds))) {
                scale = inhale ? 1.0 : 0.55
            }
            try? await Task.sleep(for: .seconds(step.seconds))
            elapsed += step.seconds
        }
        if Task.isCancelled { return }
        finish(completed: true)
    }

    private func stopEarly() {
        task?.cancel()
        speech.stop()
        finish(completed: false)
    }

    private func finish(completed: Bool) {
        UIApplication.shared.isIdleTimerDisabled = false
        if elapsed >= 20 {
            context.insert(WellbeingSession(activity: "breathing", seconds: elapsed))
        }
        if completed {
            stage = .finished
            say(Str.breathingDone)
        } else {
            stage = .idle
        }
    }

    private func leave() {
        task?.cancel()
        speech.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// Cues are spoken only if the user has voice switched on; the circle and words always show.
    private func say(_ text: String) {
        guard theme.speechEnabled else { return }
        speech.speak(text, rate: min(theme.speechRate, 0.4))
    }
}
