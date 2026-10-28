import Foundation

struct BreathingStep: Equatable {
    enum Phase: Equatable {
        case inhale
        case exhale
    }

    let phase: Phase
    let seconds: Int
}

/// A slow breathing pattern: breathe in, breathe out, repeat. Exhale is longer than inhale,
/// which most people find calming. The pattern is a starting point for a nurse to review.
struct BreathingPlan: Equatable {
    let inhaleSeconds: Int
    let exhaleSeconds: Int

    static let gentle = BreathingPlan(inhaleSeconds: 4, exhaleSeconds: 6)

    var cycleSeconds: Int { inhaleSeconds + exhaleSeconds }

    /// Whole cycles that fit in `totalSeconds`, at least one.
    func steps(totalSeconds: Int) -> [BreathingStep] {
        let cycles = max(1, totalSeconds / cycleSeconds)
        var result: [BreathingStep] = []
        for _ in 0..<cycles {
            result.append(BreathingStep(phase: .inhale, seconds: inhaleSeconds))
            result.append(BreathingStep(phase: .exhale, seconds: exhaleSeconds))
        }
        return result
    }
}
