import Foundation

/// Turns the model's guesses into the next question for the user. The app NEVER accepts a guess
/// silently: even a confident guess is shown as a yes/no question first.
enum DishDecision: Equatable {
    /// Fairly sure: ask "is it this?".
    case confirm(Dish)
    /// Not sure: show up to three likely dishes to choose from.
    case choose([Dish])
    /// No useful guess: show the whole list.
    case list

    /// Starting values. Tune them on real test photos.
    static let confirmAt = 0.6
    static let chooseAt = 0.1

    static func decide(_ guesses: [RawGuess]) -> DishDecision {
        let known = guesses
            .compactMap { guess in DishCatalog.dish(id: guess.id).map { (dish: $0, confidence: guess.confidence) } }
            .sorted { $0.confidence > $1.confidence }

        guard let top = known.first, top.confidence >= chooseAt else { return .list }
        if top.confidence >= confirmAt { return .confirm(top.dish) }
        return .choose(known.filter { $0.confidence >= chooseAt }.prefix(3).map { $0.dish })
    }
}
