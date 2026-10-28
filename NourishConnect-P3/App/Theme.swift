import SwiftUI

/// Display and voice preferences in a form every view can read from the environment.
/// Built from the saved UserSettings by RootView, so a change in Settings shows everywhere at once.
struct Theme: Equatable {
    static let scaleRange: ClosedRange<Double> = 1.0...2.0

    let scale: Double
    let highContrast: Bool
    let speechEnabled: Bool
    let speechRate: Double

    init(scale: Double = 1.4,
         highContrast: Bool = false,
         speechEnabled: Bool = true,
         speechRate: Double = 0.42) {
        self.scale = min(max(scale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        self.highContrast = highContrast
        self.speechEnabled = speechEnabled
        self.speechRate = speechRate
    }

    init(settings: UserSettings?) {
        if let s = settings {
            self.init(scale: s.textScale,
                      highContrast: s.highContrast,
                      speechEnabled: s.speechEnabled,
                      speechRate: s.speechRate)
        } else {
            self.init()
        }
    }

    /// A font whose size follows the user's text size setting.
    func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size * scale, weight: weight)
    }

    /// Button fill. `emphasis` is used for the help buttons.
    func fill(emphasis: Bool = false) -> Color {
        if highContrast { return .yellow }
        return emphasis ? .red : .blue
    }

    /// Text colour that is readable on `fill`.
    var onFill: Color {
        highContrast ? .black : .white
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
