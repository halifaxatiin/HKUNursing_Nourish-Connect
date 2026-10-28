import SwiftUI

/// Scan a barcode, look the product up, and show the result.
/// If the product is not found, or there is no network, it offers the label photo instead.
struct ScanBarcodeView: View {
    private enum Phase: Equatable {
        case scanning
        case looking
        case finished
        case notFound(String)
    }

    @Environment(\.theme) private var theme
    @EnvironmentObject private var speech: SpeechService
    @StateObject private var handle = ScannerHandle()
    @State private var phase: Phase = .scanning
    @State private var outcome: ScanOutcome?
    @State private var typed = ""

    private let client = OpenFoodFactsClient()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scannerArea
                statusArea
                manualEntry
                ReadAloudButton(text: Str.barcodeSpoken)
            }
            .padding(20)
        }
        .navigationTitle(Str.barcodeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $outcome) { ResultView(outcome: $0) }
        .speaksOnAppear(Str.barcodeSpoken)
    }

    // MARK: Pieces

    @ViewBuilder
    private var scannerArea: some View {
        if ScannerView.isSupported {
            ScannerView(mode: .barcode,
                        handle: handle,
                        isActive: phase == .scanning,
                        onBarcode: { found($0) })
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        case .scanning:
            Text(Str.barcodePrompt)
                .font(theme.font(24, weight: .semibold))
                .multilineTextAlignment(.center)
        case .looking:
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text(Str.barcodeLooking)
                    .font(theme.font(24, weight: .semibold))
            }
        case .finished:
            scanAgainButton
        case .notFound(let message):
            VStack(spacing: 16) {
                Text(message)
                    .font(theme.font(22, weight: .semibold))
                    .multilineTextAlignment(.center)
                NavigationLink(value: FoodRoute.label) {
                    BigButtonLabel(title: Str.scanLabel,
                                   hint: Str.scanLabelHint,
                                   systemImage: "text.viewfinder")
                }
                .buttonStyle(.plain)
                scanAgainButton
            }
        }
    }

    private var scanAgainButton: some View {
        Button {
            phase = .scanning
        } label: {
            Label(Str.scanAgain, systemImage: "barcode.viewfinder")
                .font(theme.font(22, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(theme.fill())
        .foregroundStyle(theme.onFill)
    }

    /// For the Simulator, damaged barcodes, and staff-assisted use.
    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Str.typeBarcode)
                .font(theme.font(18, weight: .semibold))
            HStack(spacing: 12) {
                TextField(Str.barcodeField, text: $typed)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .font(theme.font(20))
                Button(Str.lookUp) {
                    found(typed)
                }
                .font(theme.font(20, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .disabled(typed.filter(\.isNumber).count < 8)
            }
        }
    }

    // MARK: Logic

    private func found(_ code: String) {
        guard phase != .looking else { return }
        phase = .looking
        speech.speak(Str.barcodeLooking, rate: theme.speechRate)
        Task { await lookup(code) }
    }

    @MainActor
    private func lookup(_ code: String) async {
        do {
            switch try await client.lookup(barcode: code) {
            case .found(let name, let facts):
                phase = .finished
                outcome = ScanOutcome(source: .barcode, barcode: code, productName: name, facts: facts)
            case .notFound:
                show(.notFound(Str.barcodeNotFound))
            }
        } catch {
            show(.notFound(Str.barcodeOffline))
        }
    }

    private func show(_ newPhase: Phase) {
        phase = newPhase
        if case .notFound(let message) = newPhase {
            speech.speak(message, rate: theme.speechRate)
        }
    }
}
