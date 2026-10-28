import SwiftUI
import PhotosUI

/// Photograph the nutrition label (or pick a photo), read it on the phone, and show the result.
struct ScanLabelView: View {
    private enum Phase: Equatable {
        case ready
        case reading
        case failed
    }

    @Environment(\.theme) private var theme
    @EnvironmentObject private var speech: SpeechService
    @StateObject private var handle = ScannerHandle()
    @State private var phase: Phase = .ready
    @State private var outcome: ScanOutcome?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cameraArea
                statusArea
                photoPicker
                ReadAloudButton(text: Str.labelSpoken)
            }
            .padding(20)
        }
        .navigationTitle(Str.labelTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $outcome) { ResultView(outcome: $0) }
        .speaksOnAppear(Str.labelSpoken)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await process(image)
                }
                pickerItem = nil
            }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var cameraArea: some View {
        if ScannerView.isSupported {
            VStack(spacing: 16) {
                ScannerView(mode: .text,
                            handle: handle,
                            isActive: outcome == nil && phase != .reading)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Button {
                    Task { await capture() }
                } label: {
                    Label(Str.takePhoto, systemImage: "camera.fill")
                        .font(theme.font(26, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 72)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.fill())
                .foregroundStyle(theme.onFill)
                .disabled(phase == .reading)
            }
        } else {
            Text(Str.scannerUnavailable)
                .font(theme.font(20))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 20).stroke(Color.secondary, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        switch phase {
        case .ready:
            EmptyView()
        case .reading:
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text(Str.labelReading)
                    .font(theme.font(24, weight: .semibold))
            }
        case .failed:
            Text(Str.labelUnreadable)
                .font(theme.font(22, weight: .semibold))
                .multilineTextAlignment(.center)
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label(Str.pickPhoto, systemImage: "photo.on.rectangle")
                .font(theme.font(20, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(phase == .reading)
    }

    // MARK: Logic

    @MainActor
    private func capture() async {
        do {
            let image = try await handle.capturePhoto()
            await process(image)
        } catch {
            fail()
        }
    }

    @MainActor
    private func process(_ image: UIImage) async {
        phase = .reading
        speech.speak(Str.labelReading, rate: theme.speechRate)
        do {
            let text = try await LabelReader.recognizeText(in: image)
            let facts = LabelParser.parse(text)
            if facts.hasRatableValues {
                phase = .ready
                outcome = ScanOutcome(source: .label, barcode: nil, productName: nil, facts: facts)
            } else {
                fail()
            }
        } catch {
            fail()
        }
    }

    private func fail() {
        phase = .failed
        speech.speak(Str.labelUnreadable, rate: theme.speechRate)
    }
}
