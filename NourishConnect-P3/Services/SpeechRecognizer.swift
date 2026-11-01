import AVFoundation
import Speech

/// Turns the user's voice into text for the chat, in Hong Kong Cantonese (zh-HK).
/// Uses Apple's on-device recognition when the phone supports it for this language; otherwise
/// Apple's servers handle the audio. Cantonese recognition quality must be tested on the real phone.
@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var permissionDenied = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-HK"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false

    /// False when this phone has no Cantonese recogniser. The chat then hides the microphone button.
    var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    func start() async {
        guard !isListening, let recognizer, recognizer.isAvailable else { return }
        guard await requestPermissions() else {
            permissionDenied = true
            return
        }
        permissionDenied = false
        transcript = ""

        do {
            // Audio session changes run on a background queue so the screen never freezes.
            try await AudioSessionCoordinator.shared.prepareForRecording()

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request

            Self.installTap(on: engine.inputNode, request: request)
            tapInstalled = true
            engine.prepare()
            try engine.start()

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = (result?.isFinal ?? false) || error != nil
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if isFinal { self.finish() }
                }
            }
            isListening = true
        } catch {
            finish()
        }
    }

    /// Ends the recording. The final text arrives a moment later and `isListening` then becomes false.
    func stop() {
        guard isListening else { return }
        if engine.isRunning { engine.stop() }
        request?.endAudio()
        // Safety net in case the recogniser never reports a final result.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.isListening == true { self?.finish() }
        }
    }

    private func finish() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning { engine.stop() }
        request?.endAudio()
        request = nil
        task = nil
        // Back to playback so the Cantonese voice can speak again.
        Task { await AudioSessionCoordinator.shared.ensurePlayback() }
        isListening = false
    }

    private func requestPermissions() async -> Bool {
        let speechAllowed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAllowed else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Built outside the main actor because the audio system calls it on its own thread.
    nonisolated private static func installTap(on node: AVAudioInputNode,
                                               request: SFSpeechAudioBufferRecognitionRequest) {
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }
}
