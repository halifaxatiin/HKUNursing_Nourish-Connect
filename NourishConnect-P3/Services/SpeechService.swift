import AVFoundation
import SwiftUI

/// Does ALL AVAudioSession work on one background queue.
/// Changing the audio session can block for 100 ms or more while the system sets up audio. Doing it
/// on the main thread (at start-up, and before every sentence) froze the screen. Callers just await.
final class AudioSessionCoordinator: @unchecked Sendable {
    static let shared = AudioSessionCoordinator()

    private enum Mode { case none, playback, recording }
    private let queue = DispatchQueue(label: "nourish.audio-session", qos: .userInitiated)
    /// Only read or written on `queue`.
    private var mode: Mode = .none

    /// Runs on `queue`.
    private func applyPlayback() {
        let session = AVAudioSession.sharedInstance()
        if mode != .playback {
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            mode = .playback
        }
        // Always re-activate: a phone call or alarm can switch the session off.
        try? session.setActive(true)
    }

    /// Call once at launch. Returns at once; the work happens in the background.
    func warmUp() {
        queue.async {
            self.applyPlayback()
            // Loading the first voice is slow. Do it now, off the main thread.
            _ = AVSpeechSynthesisVoice(language: "zh-HK")
        }
    }

    func ensurePlayback() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.applyPlayback()
                continuation.resume()
            }
        }
    }

    func prepareForRecording() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                    self.mode = .recording
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

/// Reads text aloud in Hong Kong Cantonese using the phone's built-in voice.
/// Runs on the phone with no network, so it also works for the help screen.
///
/// Requests are debounced: screens ask to speak the moment they appear, and moving quickly between
/// screens used to stop and restart the synthesiser many times in a row. Now only the latest request
/// in a 150 ms window is spoken.
@MainActor
final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var pending: Task<Void, Never>?
    private lazy var voice = AVSpeechSynthesisVoice(language: "zh-HK")

    @Published private(set) var isSpeaking = false

    /// True when a zh-HK voice is installed. Views can show Str.noCantoneseVoice when false.
    var hasCantoneseVoice: Bool {
        voice != nil
    }

    override init() {
        super.init()
        synthesizer.delegate = self
        AudioSessionCoordinator.shared.warmUp()
    }

    func speak(_ text: String, rate: Double) {
        guard !text.isEmpty else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await AudioSessionCoordinator.shared.ensurePlayback()
            guard !Task.isCancelled, let self else { return }

            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = self.voice
            utterance.rate = Float(min(max(rate, 0.2), 0.7))
            utterance.pitchMultiplier = 1.0
            utterance.postUtteranceDelay = 0.1
            self.synthesizer.speak(utterance)
        }
    }

    func stop() {
        pending?.cancel()
        pending = nil
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
