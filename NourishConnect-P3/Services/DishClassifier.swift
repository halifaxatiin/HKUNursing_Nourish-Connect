import UIKit
import Vision
import CoreML

/// One raw answer from the image model: a dish id and how sure the model is (0 to 1).
struct RawGuess: Equatable {
    let id: String
    let confidence: Double
}

enum DishClassifierError: Error {
    case noModel
    case badImage
}

protocol DishClassifying {
    var isAvailable: Bool { get }
    func classify(_ image: UIImage) async throws -> [RawGuess]
}

/// Runs a Core ML image classifier on the phone. The photo never leaves the phone.
///
/// The model is not included. Train one (see MEAL_MODEL.md), name it
/// `DishClassifier.mlmodel`, and add it to the app target. Until then `isAvailable` is false and
/// the app simply asks the user to pick the dish from the list.
struct CoreMLDishClassifier: DishClassifying {
    static let modelName = "DishClassifier"

    private static func modelURL() -> URL? {
        Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")
    }

    /// Loaded on first use and kept: reading the model from disk for every photo is slow.
    private static let model: VNCoreMLModel? = {
        guard let url = modelURL() else { return nil }
        return try? VNCoreMLModel(for: MLModel(contentsOf: url))
    }()

    var isAvailable: Bool { Self.modelURL() != nil }

    func classify(_ image: UIImage) async throws -> [RawGuess] {
        guard Self.modelURL() != nil else { throw DishClassifierError.noModel }
        guard let cgImage = image.cgImage else { throw DishClassifierError.badImage }
        let orientation = CGImagePropertyOrientation(uiOrientation: image.imageOrientation)

        return try await Task.detached(priority: .userInitiated) {
            guard let model = Self.model else { throw DishClassifierError.noModel }
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])
            let results = (request.results as? [VNClassificationObservation]) ?? []
            return results.prefix(5).map { RawGuess(id: $0.identifier, confidence: Double($0.confidence)) }
        }.value
    }
}
