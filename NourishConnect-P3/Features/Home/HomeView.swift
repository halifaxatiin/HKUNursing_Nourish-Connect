import SwiftUI

enum Route: Hashable {
    case food
    case mood
    case help
    case settings
}

/// Home: three large buttons, one screen's worth of choices, spoken on arrival.
struct HomeView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(Str.homeGreeting)
                    .font(theme.font(30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                NavigationLink(value: Route.food) {
                    BigButtonLabel(title: Str.food, hint: Str.foodHint, systemImage: "fork.knife")
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.mood) {
                    BigButtonLabel(title: Str.mood, hint: Str.moodHint, systemImage: "heart.fill")
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.help) {
                    BigButtonLabel(title: Str.help, hint: Str.helpHint, systemImage: "phone.fill", emphasis: true)
                }
                .buttonStyle(.plain)

                ReadAloudButton(text: Str.homeSpoken)

                NavigationLink(value: Route.settings) {
                    Label(Str.settings, systemImage: "gearshape")
                        .font(theme.font(20, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(20)
        }
        .navigationTitle(Str.appName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .food: FoodView()
            case .mood: MoodView()
            case .help: CallScreenView(reason: .helpButton)
            case .settings: SettingsView()
            }
        }
        .speaksOnAppear(Str.homeSpoken)
    }
}
