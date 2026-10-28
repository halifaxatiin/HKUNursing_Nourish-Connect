import SwiftUI
import SwiftData

/// Shows one scan: a traffic-light row for sugar and sodium, the other numbers, and a spoken summary.
/// Every result is saved on the phone as a MealEntry.
struct ResultView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    let outcome: ScanOutcome

    private var assessment: NutritionAssessment {
        NutritionAssessment.assess(outcome.facts)
    }

    private var spoken: String {
        Narration.spoken(outcome: outcome, assessment: assessment)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(outcome.productName ?? Str.resultLabelName)
                    .font(theme.font(28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if assessment.overall == nil {
                    Text(outcome.facts.basis == .perServing ? Str.perServingNote : Str.unratedNote)
                        .font(theme.font(22, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).stroke(Color.orange, lineWidth: 3))
                }

                if let level = assessment.sugar, let sugar = outcome.facts.sugarsG {
                    LevelRow(name: Str.sugarName,
                             value: "\(Narration.basisPhrase(outcome.facts.basis)) \(Narration.number(sugar)) \(Str.unitG)",
                             level: level)
                }
                if let level = assessment.sodium, let sodium = outcome.facts.sodiumMg {
                    LevelRow(name: Str.sodiumName,
                             value: "\(Narration.basisPhrase(outcome.facts.basis)) \(Narration.number(sodium)) \(Str.unitMg)",
                             level: level)
                }

                otherFacts

                Text(Str.checkPackage)
                    .font(theme.font(18))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

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
        .navigationTitle(Str.resultTitle)
        .navigationBarTitleDisplayMode(.inline)
        .speaksOnAppear(spoken)
        .onAppear(perform: saveOnce)
    }

    /// Numbers that are shown but not rated.
    @ViewBuilder
    private var otherFacts: some View {
        let f = outcome.facts
        let rows: [(String, String)] = [
            f.carbsG.map { (Str.carbsName, "\(Narration.number($0)) \(Str.unitG)") },
            f.energyKcal.map { (Str.energyName, "\(Narration.number($0)) \(Str.unitKcal)") },
            f.fatG.map { (Str.fatName, "\(Narration.number($0)) \(Str.unitG)") },
            f.satFatG.map { (Str.satFatName, "\(Narration.number($0)) \(Str.unitG)") },
            f.transFatG.map { (Str.transFatName, "\(Narration.number($0)) \(Str.unitG)") },
            f.proteinG.map { (Str.proteinName, "\(Narration.number($0)) \(Str.unitG)") }
        ].compactMap { $0 }

        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(Str.otherFacts)
                    .font(theme.font(20, weight: .semibold))
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0)
                        Spacer()
                        Text(row.1)
                    }
                    .font(theme.font(20))
                    .accessibilityElement(children: .combine)
                }
                if f.carbsG != nil {
                    Text(Str.carbsNote)
                        .font(theme.font(16))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.5), lineWidth: 1))
        }
    }

    private func saveOnce() {
        guard !saved else { return }
        saved = true
        let f = outcome.facts
        var note = "basis=\(f.basis.rawValue)"
        if let s = f.sugarsG { note += "; sugars_g=\(Narration.number(s))" }
        if let n = f.sodiumMg { note += "; sodium_mg=\(Narration.number(n))" }
        if let code = outcome.barcode { note += "; barcode=\(code)" }

        context.insert(MealEntry(
            source: outcome.source.rawValue,
            name: outcome.productName ?? Str.resultLabelName,
            rating: assessment.overall?.storageKey ?? "unrated",
            note: note
        ))
    }
}

/// One traffic-light row. Meaning is carried by the symbol and the word as well as the colour.
struct LevelRow: View {
    @Environment(\.theme) private var theme

    let name: String
    let value: String
    let level: Level

    private var tint: Color {
        switch level {
        case .lower: return .green
        case .middle: return .orange
        case .higher: return .red
        }
    }

    private var symbol: String {
        switch level {
        case .lower: return "checkmark.circle.fill"
        case .middle: return "exclamationmark.triangle.fill"
        case .higher: return "exclamationmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(theme.font(40, weight: .bold))
                .foregroundStyle(tint)
                .frame(minWidth: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(name)：\(Narration.levelWord(level))")
                    .font(theme.font(28, weight: .bold))
                Text(value)
                    .font(theme.font(20))
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tint.opacity(0.18)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(tint, lineWidth: 3))
        .accessibilityElement(children: .combine)
    }
}
