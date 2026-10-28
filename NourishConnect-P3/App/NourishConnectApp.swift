import SwiftUI
import SwiftData

@main
struct NourishConnectApp: App {
    @StateObject private var speech = SpeechService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(speech)
        }
        .modelContainer(for: [
            UserSettings.self,
            EmergencyContact.self,
            MealEntry.self,
            MoodEntry.self,
            AlertEvent.self,
            WellbeingSession.self
        ])
    }
}
