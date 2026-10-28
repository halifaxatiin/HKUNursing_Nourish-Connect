import AVFoundation
import SwiftUI

/// Reads text aloud in Hong Kong Cantonese using the phone's built-in voice.
/// Runs on the phone with no network, so it also works for the help screen later.
@MainActor
final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    @Published private(set) var isSpeaking = false

    /// True when a zh-HK voice is installed. Views can show Str.noCantoneseVoice when false.
    var hasCantoneseVoice: Bool {
        AVSpeechSynthesisVoice(language: "zh-HK") != nil
    }

    override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }

    func speak(_ text: String, rate: Double) {
        guard !text.isEmpty else { return }
        stop()
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-HK")
        utterance.rate = Float(min(max(rate, 0.2), 0.7))
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
