import Foundation
import CoreML
import Vision
import UIKit
import Combine

// MARK: - ML Classifier
// Wraps GAIA_Classifier.mlmodel produced by the Python training pipeline.
//
// Python ExportWrapper bakes normalisation in: x = (x/255 - mean) / std → softmax
// CoreML ImageType scale=1/255 is applied automatically by the runtime.
final class MLClassifier: ObservableObject {

    // MARK: - Singleton
    static let shared = MLClassifier()

    // MARK: - Published state (drives UI progress ring)
    @Published var isAnalyzing = false
    @Published var progress:    Float = 0

    // MARK: - Private
    private var model:      VNCoreMLModel?
    private let modelQueue  = DispatchQueue(label: "gaia.mlclassifier", qos: .userInitiated)

    // Must exactly match CLASS_NAMES order from Python training
    // ["Covid", "Normal", "Tuberculosis", "Viral Pneumonia"]
    private let classLabels: [String] = ["Covid", "Normal", "Tuberculosis", "Viral Pneumonia"]

    // MARK: - Init
    private init() { loadModel() }

    // MARK: - Model Loading
    private func loadModel() {
        print("📦 Bundle: \(Bundle.main.bundlePath)")
        let all = (try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath)) ?? []
        let models = all.filter { $0.contains("GAIA") || $0.contains("mlmodel") || $0.contains("mlmodelc") || $0.contains("mlpackage") }
        if models.isEmpty { print("  ⚠️  No model files in bundle — check Target Membership in Xcode") }
        else              { models.forEach { print("  ✅ \($0)") } }

        guard let url =
            Bundle.main.url(forResource: "GAIA_Classifier", withExtension: "mlmodel")   ??
            Bundle.main.url(forResource: "GAIA_Classifier", withExtension: "mlmodelc")  ??
            Bundle.main.url(forResource: "GAIA_Classifier", withExtension: "mlpackage")
        else {
            print("❌ GAIA_Classifier not found.")
            print("   → Xcode: click GAIA_Classifier.mlmodel → right panel → Target Membership → tick ✅")
            print("   → Then: Cmd+Shift+K → rebuild")
            return
        }
        print("🔍 Loading: \(url.lastPathComponent)")
        do {
            let cfg          = MLModelConfiguration()
            cfg.computeUnits = .all                          // CPU + GPU + Neural Engine
            let raw          = try MLModel(contentsOf: url, configuration: cfg)
            self.model       = try VNCoreMLModel(for: raw)
            print("✅ GAIA_Classifier loaded")
        } catch {
            print("❌ Load failed: \(error)")
        }
    }

    // MARK: - Predict
    func predict(image: UIImage, completion: @escaping (Result<PredictionResult, Error>) -> Void) {
        guard let model else {
            print("❌ model is nil — see loadModel() logs above")
            completion(.failure(ClassifierError.modelNotLoaded))
            return
        }

        // 1. Get the raw CGImage (No manual redrawing/color space shifting!)
        guard let cgImage = image.cgImage else {
            completion(.failure(ClassifierError.imagePreprocessingFailed))
            return
        }

        // 2. Extract the true camera orientation natively
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        DispatchQueue.main.async { self.isAnalyzing = true; self.progress = 0.2 }

        modelQueue.async { [weak self] in
            guard let self else { return }
            do {
                let request = VNCoreMLRequest(model: model) { [weak self] req, err in
                    guard let self else { return }
                    if let err {
                        DispatchQueue.main.async {
                            self.finish(progress: 0)
                            completion(.failure(err))
                        }
                        return
                    }
                    do {
                        let result = try self.parse(req.results)
                        DispatchQueue.main.async {
                            self.finish(progress: 1.0)
                            completion(.success(result))
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.finish(progress: 0)
                            completion(.failure(error))
                        }
                    }
                }

                // 3. CRITICAL FIX: Match Python's PIL.resize exactly
                // Python's resize squashes the image. .scaleFill replicates this perfectly.
                // This prevents Vision from cropping out critical edges of the X-ray.
                request.imageCropAndScaleOption = .scaleFill

                DispatchQueue.main.async { self.progress = 0.5 }

                // 4. Pass the raw image and its orientation. Vision handles the rest natively.
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                try handler.perform([request])

                DispatchQueue.main.async { self.progress = 0.9 }

            } catch {
                DispatchQueue.main.async {
                    self.finish(progress: 0)
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Parse Vision output
    private func parse(_ results: [VNObservation]?) throws -> PredictionResult {

        // Path A — VNClassificationObservation (standard neuralnetwork output)
        if let cls = results as? [VNClassificationObservation], !cls.isEmpty {
            var probs: [String: Float] = [:]
            cls.forEach { probs[$0.identifier] = $0.confidence }
            classLabels.forEach { if probs[$0] == nil { probs[$0] = 0 } }

            print("🧠 Predictions:")
            cls.sorted { $0.confidence > $1.confidence }
               .forEach { print("   \($0.identifier): \(String(format: "%.1f%%", $0.confidence * 100))") }

            guard let top  = cls.max(by: { $0.confidence < $1.confidence }),
                  let cond = DiseaseCondition(rawValue: top.identifier)
            else {
                print("❌ Label mismatch: '\(cls.first?.identifier ?? "nil")'")
                print("   Expected: \(classLabels.joined(separator: " | "))")
                print("   Check ScanResult.swift rawValues match these exactly.")
                throw ClassifierError.invalidPrediction
            }
            return PredictionResult(condition: cond, confidence: top.confidence,
                                    allProbabilities: probs, timestamp: Date())
        }

        // Path B — Raw MLMultiArray (fallback for custom output layers)
        if let feat  = results as? [VNCoreMLFeatureValueObservation],
           let first = feat.first,
           let arr   = first.featureValue.multiArrayValue {
            print("🧠 Raw array output")
            var probs: [String: Float] = [:]
            let n = min(arr.count, classLabels.count)
            for i in 0..<n { probs[classLabels[i]] = arr[i].floatValue }
            guard let top  = probs.max(by: { $0.value < $1.value }),
                  let cond = DiseaseCondition(rawValue: top.key)
            else { throw ClassifierError.invalidPrediction }
            return PredictionResult(condition: cond, confidence: top.value,
                                    allProbabilities: probs, timestamp: Date())
        }

        print("❌ Unrecognised output: \(String(describing: results))")
        throw ClassifierError.invalidPrediction
    }

    private func finish(progress p: Float) {
        isAnalyzing = false
        self.progress = p
    }
}

// MARK: - Errors
enum ClassifierError: LocalizedError {
    case modelNotLoaded, imagePreprocessingFailed, invalidPrediction
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "AI model could not be loaded. In Xcode, check GAIA_Classifier.mlmodel → Target Membership is enabled, then Clean & rebuild."
        case .imagePreprocessingFailed:
            return "Could not process this image. Please try a different photo."
        case .invalidPrediction:
            return "The model returned an unexpected result. Please try again."
        }
    }
}

// MARK: - UIImage Orientation Helper
// Translates UIKit's orientation into the format Vision expects natively
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
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
