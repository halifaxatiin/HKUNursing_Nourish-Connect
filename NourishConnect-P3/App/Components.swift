import SwiftUI

/// A large, full-width button face: icon, title and one short hint line.
struct BigButtonLabel: View {
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    let title: String
    let hint: String
    let systemImage: String
    var emphasis: Bool = false

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(theme.font(34, weight: .semibold))
                .frame(minWidth: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(theme.font(30, weight: .bold))
                Text(hint)
                    .font(theme.font(18))
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.onFill)
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: sizeClass == .regular ? 140 : 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.fill(emphasis: emphasis))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white, lineWidth: theme.highContrast ? 3 : 0)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Reads the given text aloud when tapped, whether or not automatic reading is on.
struct ReadAloudButton: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var speech: SpeechService

    let text: String

    var body: some View {
        Button {
            speech.speak(text, rate: theme.speechRate)
        } label: {
            Label(Str.readAloud, systemImage: "speaker.wave.2.fill")
                .font(theme.font(22, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

/// Reads `text` aloud each time the screen appears, if automatic reading is on.
/// A new reading stops any earlier one, so moving between screens never overlaps voices.
struct SpeakOnAppear: ViewModifier {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var speech: SpeechService

    let text: String

    func body(content: Content) -> some View {
        content.task {
            if theme.speechEnabled {
                speech.speak(text, rate: theme.speechRate)
            }
        }
    }
}

extension View {
    func speaksOnAppear(_ text: String) -> some View {
        modifier(SpeakOnAppear(text: text))
    }
}

/// The app is built as one column of large controls. On iPad that column could stretch
/// across the whole screen, so it is capped and centred. On iPhone the screen is already
/// narrower than the cap, so the layout there is unchanged.
enum ResponsiveLayout {
    /// Widest a column of content is allowed to grow, in points.
    static let readableWidth: CGFloat = 680

    /// The width a column should use inside an available width.
    static func columnWidth(available: CGFloat, max: CGFloat = readableWidth) -> CGFloat {
        min(available, max)
    }
}

struct ContentColumn: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Caps the width of a screen's content and centres it. A no-op on narrow screens.
    func contentColumn(_ maxWidth: CGFloat = ResponsiveLayout.readableWidth) -> some View {
        modifier(ContentColumn(maxWidth: maxWidth))
    }
}
