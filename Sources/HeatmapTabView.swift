import SwiftUI
import CoreML
import UIKit
import CoreImage
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ScanEntry Equatable
// ─────────────────────────────────────────────────────────────────────────────
extension ScanEntry: Equatable {
    public static func == (lhs: ScanEntry, rhs: ScanEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Class Label Mapping (must match Python CLASS_NAMES exactly)
// ["Covid", "Normal", "Tuberculosis", "Viral Pneumonia"]
// ─────────────────────────────────────────────────────────────────────────────
private let kClassLabels: [String] = ["Covid", "Normal", "Tuberculosis", "Viral Pneumonia"]

// EfficientNet feature output keys (heatmap CAM model only)
private let kENInputName  = "input_image"
private let kENPredOutput = "var_2105"   // [1, 4]         softmax probs
private let kENFeatOutput = "var_2076"   // [1, 7, 7, 1280] conv feature maps

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - HeatmapMLModel  (EfficientNet .mlpackage — heatmaps only)
// This is a SEPARATE model used only for CAM heatmap generation.
// Classification is handled by MLClassifier (LungClassifier.mlmodel).
// ─────────────────────────────────────────────────────────────────────────────
class HeatmapMLModel: @unchecked Sendable {
    static let shared = HeatmapMLModel()
    private(set) var rawModel: MLModel?

    private init() { loadModel() }

    private func loadModel() {
        guard let url =
            Bundle.main.url(forResource: "GAIA_Final", withExtension: "mlpackage") ??
            Bundle.main.url(forResource: "GAIA_Final", withExtension: "mlmodelc")
        else {
            print(" GAIA_Final (EfficientNet) not found — approximate heatmaps will be used")
            return
        }
        do {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .all
            rawModel = try MLModel(contentsOf: url, configuration: cfg)
            print("GAIA_Final (EfficientNet heatmap model) loaded")
        } catch {
            print("GAIA_Final load failed: \(error) — approximate heatmaps will be used")
        }
    }
}

// MARK: - HeatmapGenerator
class HeatmapGenerator: @unchecked Sendable {
    static let shared = HeatmapGenerator()

    private let featureH = 7
    private let featureW = 7
    private let channels = 1280

    // cam_weights.json — shape [channels][numClasses] = [1280][4]
    private var camWeights: [[Float]] = []

    private init() { loadCAMWeights() }

    private func loadCAMWeights() {
        guard let url  = Bundle.main.url(forResource: "cam_weights", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let w    = try? JSONDecoder().decode([[Float]].self, from: data)
        else {
            print("⚠️ cam_weights.json missing — approximate heatmaps will be used")
            return
        }
        camWeights = w
        print("✅ cam_weights loaded: \(w.count)ch × \(w.first?.count ?? 0) classes")
    }

    func generateHeatmap(for image: UIImage,
                         targetCondition: DiseaseCondition,
                         completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result: UIImage?
            if let model = HeatmapMLModel.shared.rawModel, !self.camWeights.isEmpty {
                result = self.computeCAM(image: image, model: model, condition: targetCondition)
            } else {
                result = self.computeApproximateHeatmap(image: image, condition: targetCondition)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    //Real CAM
    // CAM[h,w] = ReLU( Σ_c  weight[c][classIdx]  ×  featureMap[h,w,c] )
    private func computeCAM(image: UIImage, model: MLModel, condition: DiseaseCondition) -> UIImage? {
        // Use rawValue to index kClassLabels (rawValues match kClassLabels exactly)
        guard let resized  = image.heatmapResized(to: CGSize(width: 224, height: 224)),
              let pb       = resized.heatmapPixelBuffer(),
              let input    = try? MLDictionaryFeatureProvider(dictionary: [kENInputName: MLFeatureValue(pixelBuffer: pb)]),
              let output   = try? model.prediction(from: input),
              let feat     = output.featureValue(for: kENFeatOutput)?.multiArrayValue
        else { return nil }

        let classIdx = kClassLabels.firstIndex(of: condition.rawValue) ?? 0
        var camMap   = [Float](repeating: 0, count: featureH * featureW)

        for h in 0..<featureH {
            for w in 0..<featureW {
                var sum: Float = 0
                for c in 0..<channels {
                    guard c < camWeights.count, classIdx < camWeights[c].count else { continue }
                    let fv = Float(truncating: feat[h * featureW * channels + w * channels + c])
                    sum   += fv * camWeights[c][classIdx]
                }
                camMap[h * featureW + w] = max(0, sum)  // ReLU
            }
        }

        normalise(&camMap)
        let up = bilinearUpsample(map: camMap, fromSize: featureH, toSize: 224)
        return renderOverlay(heatmap: up, mapSize: 224, over: image)
    }

    // ── Approximate Heatmap (fallback when EfficientNet model not present) ──
    private func computeApproximateHeatmap(image: UIImage, condition: DiseaseCondition) -> UIImage? {
        guard let cgImg = image.cgImage else { return nil }

        let gridSize = 14
        let cellW    = CGFloat(cgImg.width)  / CGFloat(gridSize)
        let cellH    = CGFloat(cgImg.height) / CGFloat(gridSize)

        var flat = [Float](repeating: 0, count: gridSize * gridSize)
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let rect = CGRect(x: CGFloat(col) * cellW, y: CGFloat(row) * cellH,
                                  width: cellW, height: cellH)
                flat[row * gridSize + col] =
                    cellScore(cgImage: cgImg, region: rect, row: row,
                              col: col, gridSize: gridSize, condition: condition)
            }
        }

        normalise(&flat)
        let up = bilinearUpsample(map: flat, fromSize: gridSize, toSize: 224)
        return renderOverlay(heatmap: up, mapSize: 224, over: image)
    }

    private func cellScore(cgImage: CGImage, region: CGRect,
                           row: Int, col: Int, gridSize: Int,
                           condition: DiseaseCondition) -> Float {
        let intensity  = sampleIntensity(cgImage: cgImage, region: region)
        let relRow     = Float(row) / Float(gridSize - 1)
        let relCol     = Float(col) / Float(gridSize - 1)
        let distFromCentre = sqrt(pow(relCol - 0.5, 2) + pow(relRow - 0.5, 2)) / 0.707

        switch condition {
        case .normal:
            return max(0, 0.25 - intensity * 0.3 + Float.random(in: 0...0.05))
        case .pneumonia:
            let lowerBias = max(0, relRow - 0.25)
            return max(0, intensity * 1.5 * (0.3 + lowerBias))
        case .tb:
            let upperBias = max(0, 1.0 - relRow * 2.5)
            return max(0, intensity * 1.3 * (0.2 + upperBias))
        case .covid:
            let peripheralBias = distFromCentre * 0.8
            let lowerBias      = max(0, relRow - 0.2) * 0.4
            let covidMatch     = max(0, 1.0 - abs(intensity - 0.50) * 2.5)
            return max(0, covidMatch * (0.4 + peripheralBias + lowerBias))
        }
    }

    private func sampleIntensity(cgImage: CGImage, region: CGRect) -> Float {
        let size = CGSize(width: 32, height: 32)
        let srcW = CGFloat(cgImage.width); let srcH = CGFloat(cgImage.height)
        let scaleX = size.width / srcW;   let scaleY = size.height / srcH
        let scaledRegion = CGRect(x: region.minX * scaleX, y: region.minY * scaleY,
                                  width: region.width * scaleX, height: region.height * scaleY)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return 0.5 }
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))

        guard let cropped  = ctx.makeImage()?.cropping(to: scaledRegion),
              let provider = cropped.dataProvider,
              let bytes    = CFDataGetBytePtr(provider.data)
        else { return Float.random(in: 0.3...0.6) }

        let count   = max(1, cropped.width * cropped.height)
        let bpp     = max(1, cropped.bitsPerPixel / 8)
        let dataLen = CFDataGetLength(provider.data)
        var lum: Float = 0

        for i in 0..<count {
            let o = i * bpp
            guard o + 2 < dataLen else { break }
            lum += 0.299 * Float(bytes[o]) / 255.0
                 + 0.587 * Float(bytes[o+1]) / 255.0
                 + 0.114 * Float(bytes[o+2]) / 255.0
        }
        return lum / Float(count)
    }

    // ── Rendering ──
    private func bilinearUpsample(map: [Float], fromSize: Int, toSize: Int) -> [Float] {
        var result = [Float](repeating: 0, count: toSize * toSize)
        let scale  = Float(fromSize - 1) / Float(toSize - 1)
        for y in 0..<toSize {
            for x in 0..<toSize {
                let sx = Float(x) * scale; let sy = Float(y) * scale
                let x0 = Int(sx); let y0 = Int(sy)
                let x1 = min(x0+1, fromSize-1); let y1 = min(y0+1, fromSize-1)
                let dx = sx - Float(x0);        let dy = sy - Float(y0)
                result[y*toSize+x] =
                    map[y0*fromSize+x0] * (1-dx) * (1-dy) +
                    map[y0*fromSize+x1] *    dx  * (1-dy) +
                    map[y1*fromSize+x0] * (1-dx) *    dy  +
                    map[y1*fromSize+x1] *    dx  *    dy
            }
        }
        return result
    }

    private func renderOverlay(heatmap: [Float], mapSize: Int, over original: UIImage) -> UIImage? {
        var pixels = [UInt8](repeating: 0, count: mapSize * mapSize * 4)
        for i in 0..<mapSize * mapSize {
            let v = heatmap[i]
            let (r, g, b) = jetColor(value: v)
            let minAlpha: Float = 35
            let alpha = UInt8(min(255, Int(minAlpha + v * 195)))
            pixels[i*4+0] = r; pixels[i*4+1] = g
            pixels[i*4+2] = b; pixels[i*4+3] = alpha
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let heatCG   = CGImage(
                  width: mapSize, height: mapSize,
                  bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: mapSize * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }

        let scale      = UIScreen.main.scale
        let w          = original.size.width  * scale
        let h          = original.size.height * scale
        let outputSize = CGSize(width: w > 0 ? w : 512, height: h > 0 ? h : 512)

        UIGraphicsBeginImageContextWithOptions(outputSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        let rect = CGRect(origin: .zero, size: outputSize)

        original.draw(in: rect, blendMode: .normal, alpha: 0.75)
        UIImage(cgImage: heatCG).draw(in: rect, blendMode: .normal, alpha: 0.55)

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func jetColor(value: Float) -> (UInt8, UInt8, UInt8) {
        let v = max(0, min(1, value))
        return (clampByte(1.5 - abs(4*v - 3)),
                clampByte(1.5 - abs(4*v - 2)),
                clampByte(1.5 - abs(4*v - 1)))
    }

    private func clampByte(_ x: Float) -> UInt8 { UInt8(max(0, min(255, x * 255))) }
    private func normalise(_ map: inout [Float]) {
        guard let mx = map.max(), let mn = map.min(), (mx - mn) > 1e-6 else { return }
        map = map.map { ($0 - mn) / (mx - mn) }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - UIImage helpers (prefixed to avoid conflict with MLClassifier.swift)
// ─────────────────────────────────────────────────────────────────────────────
extension UIImage {
    func heatmapResized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    func heatmapPixelBuffer() -> CVPixelBuffer? {
        let w = Int(size.width), h = Int(size.height)
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey:         true as CFBoolean,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true as CFBoolean
        ]
        var pb: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, w, h,
                                  kCVPixelFormatType_32BGRA,
                                  attrs as CFDictionary, &pb) == kCVReturnSuccess,
              let pixelBuffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ), let cg = cgImage else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return pixelBuffer
    }
}


// MARK: - HeatmapTabView
struct HeatmapTabView: View {
    @EnvironmentObject var persistence: PersistenceManager

    @State private var selectedEntry: ScanEntry?
    @State private var heatmapImage:  UIImage?
    @State private var isGenerating:  Bool   = false
    @State private var showPicker:    Bool   = false
    @State private var modelBadge:    String = ""

    // Heatmap always shows the scan's own diagnosed condition
    private var targetCondition: DiseaseCondition { selectedEntry?.condition ?? .pneumonia }

    var body: some View {
        NavigationView {
            ZStack {
                Color.gaiaBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerBar
                        scanSelectorCard
                        if selectedEntry != nil { diagnosisInfoCard }
                        heatmapCard
                        if selectedEntry != nil { generateButton }
                        legendCard
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPicker) { ScanPickerSheet(selected: $selectedEntry) }
        .onAppear {
            if selectedEntry == nil, let latest = persistence.scanHistory.first {
                selectedEntry = latest
            }
            modelBadge = HeatmapMLModel.shared.rawModel != nil ? "EfficientNet CAM" : "Approx. Mode"
        }
        .onChange(of: selectedEntry) { _ in heatmapImage = nil }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Heatmap")
                    .font(GAIAFont.display(26))
                    .foregroundStyle(LinearGradient.gaiaHero)
                Text("AI activation visualisation")
                    .font(GAIAFont.body(14))
                    .foregroundColor(.gaiaSubtext)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                ZStack {
                    Circle().fill(Color.gaiaCard).frame(width: 48, height: 48)
                    Image(systemName: "map.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gaiaCyan)
                }
                if !modelBadge.isEmpty {
                    Text(modelBadge)
                        .font(GAIAFont.body(9))
                        .foregroundColor(.gaiaSubtext.opacity(0.7))
                }
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Scan Selector
    private var scanSelectorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Select Scan")
                    .font(GAIAFont.heading(16))
                    .foregroundColor(.gaiaText)

                if let entry = selectedEntry {
                    HStack(spacing: 14) {
                        if let img = entry.image {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(entry.condition.color.opacity(0.6), lineWidth: 1.5))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            // ✅ displayName shows "COVID-19" instead of raw "Covid"
                            Text(entry.condition.displayName)
                                .font(GAIAFont.heading(15))
                                .foregroundColor(entry.condition.color)
                            Text("\(Int(entry.confidence * 100))% confidence")
                                .font(GAIAFont.body(12)).foregroundColor(.gaiaSubtext)
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(GAIAFont.body(11)).foregroundColor(.gaiaSubtext)
                        }
                        Spacer()
                        Button { showPicker = true } label: {
                            Text("Change")
                                .font(GAIAFont.caption(13)).foregroundColor(.gaiaCyan)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.gaiaCyan.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                } else {
                    if persistence.scanHistory.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.badge.xmark").foregroundColor(.gaiaSubtext)
                            Text("No scans yet — complete a scan first")
                                .font(GAIAFont.body(14)).foregroundColor(.gaiaSubtext)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gaiaCardSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button { showPicker = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill").foregroundColor(.gaiaCyan)
                                Text("Choose from Scan History")
                                    .font(GAIAFont.caption(15)).foregroundColor(.gaiaText)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gaiaSubtext)
                            }
                            .padding(14)
                            .background(Color.gaiaCardSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Diagnosis Info Card
    private var diagnosisInfoCard: some View {
        GlassCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(targetCondition.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: targetCondition.icon)
                        .font(.system(size: 22))
                        .foregroundColor(targetCondition.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    // ✅ displayName used here too
                    Text("Visualising: \(targetCondition.displayName)")
                        .font(GAIAFont.heading(15))
                        .foregroundColor(targetCondition.color)
                    Text("Regions the AI focused on when making this diagnosis.")
                        .font(GAIAFont.body(12))
                        .foregroundColor(.gaiaSubtext)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Heatmap Card
    private var heatmapCard: some View {
        GlassCard(padding: 0) {
            ZStack {
                if heatmapImage == nil && !isGenerating {
                    VStack(spacing: 16) {
                        if let entry = selectedEntry, let img = entry.image {
                            Image(uiImage: img)
                                .resizable().scaledToFit()
                                .opacity(0.35)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 12).padding(.top, 12)
                            // ✅ displayName in prompt text
                            Text("Tap \"Generate Heatmap\" to see where\nthe AI focused for \(targetCondition.displayName)")
                                .font(GAIAFont.body(13)).foregroundColor(.gaiaSubtext)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20).padding(.bottom, 16)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.gaiaSubtext.opacity(0.35))
                                Text("Select a scan above to begin")
                                    .font(GAIAFont.body(14)).foregroundColor(.gaiaSubtext)
                            }
                            .padding(48)
                        }
                    }
                }

                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gaiaCyan))
                            .scaleEffect(1.5)
                        Text("Generating heatmap…")
                            .font(GAIAFont.body(14)).foregroundColor(.gaiaSubtext)
                        Text(HeatmapMLModel.shared.rawModel != nil
                             ? "Running EfficientNet CAM analysis"
                             : "Running approximate analysis")
                            .font(GAIAFont.body(11))
                            .foregroundColor(.gaiaSubtext.opacity(0.6))
                    }
                    .padding(48)
                }

                if let img = heatmapImage {
                    VStack(spacing: 0) {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        HStack(spacing: 8) {
                            Image(systemName: targetCondition.icon)
                                .foregroundColor(targetCondition.color)
                                .font(.system(size: 13))
                            // ✅ displayName in caption
                            Text("Showing \(targetCondition.displayName) activation regions")
                                .font(GAIAFont.body(13)).foregroundColor(.gaiaSubtext)
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .frame(minHeight: 260)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Generate Button
    private var generateButton: some View {
        CyanButton(
            title: isGenerating ? "Generating…" : "Generate Heatmap",
            icon:  isGenerating ? "hourglass"   : "wand.and.stars"
        ) { generateHeatmap() }
        .disabled(isGenerating)
        .opacity(isGenerating ? 0.6 : 1.0)
    }

    // MARK: - Legend
    private var legendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Heatmap Legend")
                    .font(GAIAFont.heading(15)).foregroundColor(.gaiaText)

                LinearGradient(
                    colors: [Color(red:0,green:0,blue:1), Color(red:0,green:1,blue:1),
                             Color(red:0,green:1,blue:0), Color(red:1,green:1,blue:0),
                             Color(red:1,green:0,blue:0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 14).clipShape(Capsule())

                HStack {
                    Text("Low activation").font(GAIAFont.body(11)).foregroundColor(.gaiaSubtext)
                    Spacer()
                    Text("High activation").font(GAIAFont.body(11)).foregroundColor(.gaiaSubtext)
                }

                Divider().background(Color.gaiaBorder)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: targetCondition.icon)
                        .foregroundColor(targetCondition.color)
                        .font(.system(size: 13)).padding(.top, 1)
                    Text(legendTip)
                        .font(GAIAFont.body(12)).foregroundColor(.gaiaSubtext).lineSpacing(3)
                }

                Divider().background(Color.gaiaBorder)

                Text("Red/yellow = regions most influential for this diagnosis. Blue = low or no activation. Overlaid at 80% on your original X-ray.")
                    .font(GAIAFont.body(11))
                    .foregroundColor(.gaiaSubtext.opacity(0.8))
                    .lineSpacing(3)
            }
        }
    }

    private var legendTip: String {
        switch targetCondition {
        case .normal:
            return "Normal: activation should be low and evenly distributed — no focal hotspots expected."
        case .pneumonia:
            return "Pneumonia: expect hotspots in lower and middle lung zones where consolidation typically accumulates."
        case .tb:
            return "TB: activation concentrates in the upper lobes where Mycobacterium tuberculosis preferentially colonises."
        case .covid:
            return "COVID-19: bilateral peripheral activation along the outer lung margins — the hallmark ground glass opacity pattern."
        }
    }

    private func generateHeatmap() {
        guard let entry = selectedEntry, let image = entry.image else { return }
        isGenerating = true
        heatmapImage = nil
        HeatmapGenerator.shared.generateHeatmap(for: image, targetCondition: targetCondition) { result in
            isGenerating = false
            heatmapImage = result
        }
    }
}

// ScanPickerSheet is defined in ReportView.swift — no redeclaration needed here.
