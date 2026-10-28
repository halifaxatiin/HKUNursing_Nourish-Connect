import UIKit
import Vision
import ImageIO

enum LabelReaderError: Error {
    case noImage
}

/// Reads the text on a photo of a nutrition label, on the phone, with Apple's Vision framework.
/// The photo never leaves the phone.
enum LabelReader {
    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw LabelReaderError.noImage }
        let orientation = CGImagePropertyOrientation(uiOrientation: image.imageOrientation)

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Language correction can change digits, so it is off.
            request.usesLanguageCorrection = false
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            let wanted = ["zh-Hant", "en-US"].filter { supported.contains($0) }
            if !wanted.isEmpty {
                request.recognitionLanguages = wanted
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])

            let observations = request.results ?? []
            let items: [(text: String, box: CGRect)] = observations.compactMap { observation in
                guard let top = observation.topCandidates(1).first else { return nil }
                return (top.string, observation.boundingBox)
            }
            return LabelReader.layout(items)
        }.value
    }

    /// Puts recognised pieces of text back into table rows: pieces whose vertical positions
    /// overlap become one line, left to right, so "Sugars" and "12.5 g" stay together.
    /// Vision boxes are normalised with the origin at the bottom left, so higher midY = higher on the page.
    static func layout(_ items: [(text: String, box: CGRect)]) -> String {
        let sorted = items.sorted { $0.box.midY > $1.box.midY }
        var rows: [[(text: String, box: CGRect)]] = []

        for item in sorted {
            if let anchor = rows.last?.first,
               abs(anchor.box.midY - item.box.midY) < max(anchor.box.height, item.box.height) * 0.6 {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
            }
        }

        return rows
            .map { row in
                row.sorted { $0.box.minX < $1.box.minX }
                    .map { $0.text }
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
    }
}

extension CGImagePropertyOrientation {
    init(uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
