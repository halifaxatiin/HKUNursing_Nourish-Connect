import SwiftUI
import SwiftData

/// Result for a dish the user confirmed or picked. Numbers are estimates and say so.
/// Saved on the phone as a MealEntry with source "meal". The photo is not saved.
struct MealResultView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    let dish: Dish

    private var assessment: NutritionAssessment {
        NutritionAssessment.assess(dish.facts)
    }

    private var spoken: String {
        Str.mealSpokenResult(dish, assessment: assessment)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(dish.name)
                    .font(theme.font(32, weight: .bold))
                    .frame(maxWidth: .infinity)

                if let level = assessment.sugar {
                    LevelRow(name: Str.sugarName,
                             value: "\(Narration.basisPhrase(dish.facts.basis)) \(Narration.number(dish.sugarsPer100)) \(Str.unitG)",
                             level: level)
                }
                if let level = assessment.sodium {
                    LevelRow(name: Str.sodiumName,
                             value: "\(Narration.basisPhrase(dish.facts.basis)) \(Narration.number(dish.sodiumMgPer100)) \(Str.unitMg)",
                             level: level)
                }

                Text(Str.servingLine(dish))
                    .font(theme.font(20))
                    .multilineTextAlignment(.center)
                Text(Str.carbsNote)
                    .font(theme.font(16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(Str.mealEstimate)
                    .font(theme.font(20, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).stroke(Color.orange, lineWidth: 3))

                ReadAloudButton(text: spoken)

                Button {
                    dismiss()
                } label: {
                    Label(Str.scanAgain, systemImage: "arrow.uturn.backward")
                        .font(theme.font(22, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.fill())
                .foregroundStyle(theme.onFill)

                Text(Str.savedNote)
                    .font(theme.font(16))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle(Str.mealResultTitle)
        .navigationBarTitleDisplayMode(.inline)
        .speaksOnAppear(spoken)
        .onAppear(perform: saveOnce)
    }

    private func saveOnce() {
        guard !saved else { return }
        saved = true
        context.insert(MealEntry(
            source: "meal",
            name: dish.name,
            rating: assessment.overall?.storageKey ?? "unrated",
            note: "dish=\(dish.id); estimate"
        ))
    }
}
