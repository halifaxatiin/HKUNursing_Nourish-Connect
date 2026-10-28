import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [UserSettings]

    private var theme: Theme {
        Theme(settings: settingsList.first)
    }

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .environment(\.theme, theme)
        .preferredColorScheme(theme.highContrast ? .dark : nil)
        .task {
            // First launch: create the single settings record.
            let count = (try? context.fetchCount(FetchDescriptor<UserSettings>())) ?? 0
            if count == 0 {
                context.insert(UserSettings())
            }
        }
    }
}
