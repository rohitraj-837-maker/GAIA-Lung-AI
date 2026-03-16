//
// GAIA_Classifier.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class GAIA_ClassifierInput : MLFeatureProvider {

    /// Chest X-ray RGB 224x224 raw 0-255 as color (kCVPixelFormatType_32BGRA) image buffer, 224 pixels wide by 224 pixels high
    var input_image: CVPixelBuffer

    var featureNames: Set<String> { ["input_image"] }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "input_image" {
            return MLFeatureValue(pixelBuffer: input_image)
        }
        return nil
    }

    init(input_image: CVPixelBuffer) {
        self.input_image = input_image
    }

    convenience init(input_imageWith input_image: CGImage) throws {
        self.init(input_image: try MLFeatureValue(cgImage: input_image, pixelsWide: 224, pixelsHigh: 224, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!)
    }

    convenience init(input_imageAt input_image: URL) throws {
        self.init(input_image: try MLFeatureValue(imageAt: input_image, pixelsWide: 224, pixelsHigh: 224, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!)
    }

    func setInput_image(with input_image: CGImage) throws  {
        self.input_image = try MLFeatureValue(cgImage: input_image, pixelsWide: 224, pixelsHigh: 224, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

    func setInput_image(with input_image: URL) throws  {
        self.input_image = try MLFeatureValue(imageAt: input_image, pixelsWide: 224, pixelsHigh: 224, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

}


/// Model Prediction Output Type
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class GAIA_ClassifierOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// Softmax probability per class as dictionary of strings to doubles
    var var_1859: [String : Double] {
        provider.featureValue(for: "var_1859")!.dictionaryValue as! [String : Double]
    }

    /// Predicted disease class as string value
    var classLabel: String {
        provider.featureValue(for: "classLabel")!.stringValue
    }

    var featureNames: Set<String> {
        provider.featureNames
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        provider.featureValue(for: featureName)
    }

    init(var_1859: [String : Double], classLabel: String) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["var_1859" : MLFeatureValue(dictionary: var_1859 as [AnyHashable : NSNumber]), "classLabel" : MLFeatureValue(string: classLabel)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class GAIA_Classifier {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: "GAIA_Classifier", withExtension:"mlmodelc")!
    }

    /**
        Construct GAIA_Classifier instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of GAIA_Classifier.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `GAIA_Classifier.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct GAIA_Classifier instance by automatically loading the model from the app's bundle.
    */
    @available(*, deprecated, message: "Use init(configuration:) instead and handle errors appropriately.")
    convenience init() {
        try! self.init(contentsOf: type(of:self).urlOfModelInThisBundle)
    }

    /**
        Construct a model with configuration

        - parameters:
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(configuration: MLModelConfiguration) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct GAIA_Classifier instance with explicit path to mlmodelc file
        - parameters:
           - modelURL: the file url of the model

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL) throws {
        try self.init(model: MLModel(contentsOf: modelURL))
    }

    /**
        Construct a model with URL of the .mlmodelc directory and configuration

        - parameters:
           - modelURL: the file url of the model
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }

    /**
        Construct GAIA_Classifier instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, visionOS 1.0, *)
    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<GAIA_Classifier, Error>) -> Void) {
        load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
    }

    /**
        Construct GAIA_Classifier instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
    */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    class func load(configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> GAIA_Classifier {
        try await load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct GAIA_Classifier instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, visionOS 1.0, *)
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<GAIA_Classifier, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(GAIA_Classifier(model: model)))
            }
        }
    }

    /**
        Construct GAIA_Classifier instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> GAIA_Classifier {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return GAIA_Classifier(model: model)
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as GAIA_ClassifierInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as GAIA_ClassifierOutput
    */
    func prediction(input: GAIA_ClassifierInput) throws -> GAIA_ClassifierOutput {
        try prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as GAIA_ClassifierInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as GAIA_ClassifierOutput
    */
    func prediction(input: GAIA_ClassifierInput, options: MLPredictionOptions) throws -> GAIA_ClassifierOutput {
        let outFeatures = try model.prediction(from: input, options: options)
        return GAIA_ClassifierOutput(features: outFeatures)
    }

    /**
        Make an asynchronous prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as GAIA_ClassifierInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as GAIA_ClassifierOutput
    */
    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    func prediction(input: GAIA_ClassifierInput, options: MLPredictionOptions = MLPredictionOptions()) async throws -> GAIA_ClassifierOutput {
        let outFeatures = try await model.prediction(from: input, options: options)
        return GAIA_ClassifierOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        It uses the default function if the model has multiple functions.

        - parameters:
            - input_image: Chest X-ray RGB 224x224 raw 0-255 as color (kCVPixelFormatType_32BGRA) image buffer, 224 pixels wide by 224 pixels high

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as GAIA_ClassifierOutput
    */
    func prediction(input_image: CVPixelBuffer) throws -> GAIA_ClassifierOutput {
        let input_ = GAIA_ClassifierInput(input_image: input_image)
        return try prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - inputs: the inputs to the prediction as [GAIA_ClassifierInput]
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [GAIA_ClassifierOutput]
    */
    func predictions(inputs: [GAIA_ClassifierInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [GAIA_ClassifierOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [GAIA_ClassifierOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  GAIA_ClassifierOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
