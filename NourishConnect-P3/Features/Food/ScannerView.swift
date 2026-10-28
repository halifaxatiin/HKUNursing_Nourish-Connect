import SwiftUI
import VisionKit

enum ScannerMode {
    /// Reads EAN/UPC barcodes live.
    case barcode
    /// Shows the camera so the user can frame a label and take a photo.
    case text
}

enum ScannerError: Error {
    case notReady
}

/// Lets SwiftUI start, stop and take a photo with the camera scanner that UIKit owns.
@MainActor
final class ScannerHandle: ObservableObject {
    fileprivate weak var controller: DataScannerViewController?

    func start() {
        guard let controller, !controller.isScanning else { return }
        try? controller.startScanning()
    }

    func stop() {
        controller?.stopScanning()
    }

    func capturePhoto() async throws -> UIImage {
        guard let controller else { throw ScannerError.notReady }
        return try await controller.capturePhoto()
    }
}

/// Camera view built on Apple's VisionKit DataScannerViewController (iPhone XS / A12 or newer, iOS 16+).
struct ScannerView: UIViewControllerRepresentable {
    let mode: ScannerMode
    let handle: ScannerHandle
    /// The camera runs only while this is true.
    let isActive: Bool
    var onBarcode: (String) -> Void = { _ in }

    /// False on the Simulator, on old phones, or when camera access is refused.
    @MainActor
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let types: Set<DataScannerViewController.RecognizedDataType> =
            mode == .barcode
            ? [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])]
            : [.text()]

        let controller = DataScannerViewController(
            recognizedDataTypes: types,
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        handle.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onBarcode = onBarcode
        if isActive {
            handle.start()
        } else {
            handle.stop()
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onBarcode: (String) -> Void = { _ in }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    onBarcode(value)
                    return
                }
            }
        }
    }
}
