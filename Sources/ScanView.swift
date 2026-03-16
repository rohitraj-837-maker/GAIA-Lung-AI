import SwiftUI
import PhotosUI

struct ScanView: View {
    @EnvironmentObject var persistence: PersistenceManager
    @StateObject private var classifier = MLClassifier.shared

    // Advanced Accessibility Properties
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AccessibilityFocusState private var isResultFocused: Bool

    @State private var selectedImage:     UIImage?
    @State private var predictionResult:  PredictionResult?
    @State private var showImagePicker    = false
    @State private var showCamera         = false

    @State private var showEmergencyAlert = false
    @State private var errorMessage:      String?
    @State private var showError          = false
    @State private var scanAnimating      = false
    @State private var imageScale:        CGFloat = 1.0
    @State private var imageRotation:     Double  = 0
    @State private var glowOpacity:       Double  = 0.5
    @State private var showPatientForm    = false
    @State private var patientInfo        = PatientInfo()
    @State private var imagePickerItem:   PhotosPickerItem?

    var body: some View {
        NavigationView {
            ZStack {
                Color.gaiaBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        scanHeader

                        // Upload Zone
                        uploadZone

                        // Scan Button
                        if selectedImage != nil && predictionResult == nil {
                            analyzeButton
                        }

                        // Result Card
                        if let result = predictionResult {
                            ResultSummaryCard(result: result, image: selectedImage) {
                                triggerEmergencyCheck(result: result)
                            }
                            // 🎯 Focuses VoiceOver automatically when result appears
                            .accessibilityFocused($isResultFocused)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal:   .opacity
                            ))
                        }

                        // Loading Indicator
                        if classifier.isAnalyzing {
                            analysisLoader
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationBarHidden(true)
        }
        .photosPicker(isPresented: $showImagePicker, selection: $imagePickerItem, matching: .images)
        .onChange(of: imagePickerItem) { item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img  = UIImage(data: data) {
                    DispatchQueue.main.async {
                        withAnimation(.spring()) {
                            selectedImage    = img
                            predictionResult = nil
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $selectedImage)
                .ignoresSafeArea()
        }

        .sheet(isPresented: $showPatientForm) {
            PatientInfoForm(patientInfo: $patientInfo) {
                showPatientForm = false
                runAnalysis()
            }
        }
        .alert("⚠️ Medical Emergency", isPresented: $showEmergencyAlert) {
            Button("Call 911", role: .destructive) { callEmergency() }
            Button("Call 999 (UK)", role: .destructive) { callNumber("999") }
            Button("Dismiss", role: .cancel) { }
        } message: {
            Text("High-severity pattern detected. The AI analysis suggests this may require immediate medical attention. Would you like to call emergency services?")
        }
        .alert("Analysis Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Header
    private var scanHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lung Analysis")
                    .font(GAIAFont.display(28))
                    .foregroundStyle(LinearGradient.gaiaHero)

                Text("Upload a chest X-ray to begin")
                    .font(GAIAFont.body(14))
                    .foregroundColor(.gaiaSubtext)
            }
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.gaiaCyan.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "lungs.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.gaiaCyan)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Upload Zone
    private var uploadZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gaiaCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.gaiaCyan.opacity(selectedImage != nil ? 0.6 : 0.3),
                                    Color.gaiaPurple.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2,
                            antialiased: true
                        )
                )
                .shadow(color: Color.gaiaCyan.opacity(glowOpacity * 0.2), radius: 20)

            if let image = selectedImage {
                // Image preview
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .scaleEffect(imageScale)
                        .padding(12)

                    // Scanning overlay
                    if classifier.isAnalyzing {
                        ScanningOverlay()
                    }

                    // Change image button
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation { selectedImage = nil; predictionResult = nil }
                            } label: {
                                ZStack {
                                    Circle().fill(Color.black.opacity(0.7)).frame(width: 32, height: 32)
                                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                }
                            }
                            .padding(16)
                            .accessibilityLabel("Remove selected image")
                        }
                        Spacer()
                    }
                }
                .frame(height: 300)

            } else {
                // Empty state
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.gaiaHero.opacity(0.15))
                            .frame(width: 90, height: 90)

                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(LinearGradient.gaiaHero)
                    }
                    .scaleEffect(scanAnimating ? 1.05 : 1.0)
                    // 🛡️ REDUCE MOTION: Uses static size if user prefers less motion
                    .animation(reduceMotion ? .default : .easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: scanAnimating)

                    Text("Upload Chest X-Ray")
                        .font(GAIAFont.heading(18))
                        .foregroundColor(.gaiaText)

                    Text("Supports JPG, PNG, HEIC formats\nBest results with PA chest X-rays")
                        .font(GAIAFont.body(13))
                        .foregroundColor(.gaiaSubtext)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        uploadButton(icon: "photo.fill", label: "Gallery") { showImagePicker = true }
                        uploadButton(icon: "camera.fill", label: "Camera")  { showCamera     = true }
                    }
                    .padding(.top, 8)
                    
                    Text("OR TEST WITH SAMPLES")
                        .font(GAIAFont.caption(11))
                        .foregroundColor(.gaiaSubtext)
                        .padding(.top, 12)
                    
                    HStack(spacing: 8) {
                        sampleButton(label: "Normal", imageName: "Normal-4615", color: .green)
                        sampleButton(label: "COVID", imageName: "COVID-2258", color: .purple)
                        sampleButton(label: "Pneumonia", imageName: "PNEUMONIA_1749", color: .orange)
                        sampleButton(label: "TB", imageName: "TB.2488", color: .red)
                    }
                }
                .padding(32)
            }
        }
        // 🚀 CUSTOM ACTIONS & SMART LABELS
        .accessibilityLabel(selectedImage != nil ? "Chest X-Ray selected" : "X-Ray upload zone")
        .accessibilityAddTraits(selectedImage != nil ? .isImage : .isButton)
        .accessibilityAction(named: "Analyze X-Ray") {
            if selectedImage != nil { showPatientForm = true }
        }
        .accessibilityAction(named: "Clear Image") {
            if selectedImage != nil {
                withAnimation { selectedImage = nil; predictionResult = nil }
            }
        }
        .onAppear {
            if !reduceMotion {
                scanAnimating = true
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.8
                }
            } else {
                scanAnimating = false
                glowOpacity = 0.3
            }
        }
    }

    private func uploadButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15))
                Text(label).font(GAIAFont.caption(14))
            }
            .foregroundColor(.gaiaCyan)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.gaiaCyan.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.gaiaCyan.opacity(0.4), lineWidth: 1))
        }
        .accessibilityLabel("\(label) — select X-ray image")
    }

    private func sampleButton(label: String, imageName: String, color: Color) -> some View {
        Button(action: {
            if let img = UIImage(named: imageName, in: .module, with: nil) ?? UIImage(named: imageName) {
                withAnimation(.spring()) {
                    selectedImage = img
                    predictionResult = nil
                }
            } else {
                print("❌ ERROR: Could not find \(imageName) in Assets")
            }
        }) {
            Text(label)
                .font(GAIAFont.caption(12))
                .fontWeight(.bold)
                .foregroundColor(color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Analyze Button
    private var analyzeButton: some View {
        VStack(spacing: 12) {
            CyanButton(title: "Analyze X-Ray", icon: "waveform.path.ecg") {
                showPatientForm = true
            }
            .accessibilityLabel("Analyze X-Ray with AI")
            .accessibilityHint("Opens patient info form then runs lung disease classification")

            Text("AI will classify: Normal • Viral Pneumonia • TB • COVID-19")
                .font(GAIAFont.body(12))
                .foregroundColor(.gaiaSubtext)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Analysis Loader
    private var analysisLoader: some View {
        GlassCard {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gaiaBorder, lineWidth: 4)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(classifier.progress))
                        .stroke(LinearGradient.gaiaHero, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: classifier.progress)

                    Text("\(Int(classifier.progress * 100))%")
                        .font(GAIAFont.heading(14))
                        .foregroundColor(.gaiaCyan)
                }

                Text("Analyzing X-Ray...")
                    .font(GAIAFont.heading(16))
                    .foregroundColor(.gaiaText)

                Text("Running GAIA neural network inference")
                    .font(GAIAFont.body(13))
                    .foregroundColor(.gaiaSubtext)
            }
            .padding(.vertical, 8)
        }
        .transition(.opacity.combined(with: .scale))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing X-Ray. Please wait.")
    }

    // MARK: - Actions
    private func runAnalysis() {
        guard let image = selectedImage else { return }
        withAnimation { predictionResult = nil }

        classifier.predict(image: image) { result in
            switch result {
            case .success(let prediction):
                // 🔊 Haptic Success Feedback
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    predictionResult = prediction
                }
                
                // 🎯 Auto-focus VoiceOver on the result card
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isResultFocused = true
                }
                
                let combinedNotes: String = {
                    let doc  = patientInfo.doctorName.isEmpty ? "" : "Dr: \(patientInfo.doctorName)"
                    let note = patientInfo.notes
                    return [doc, note].filter { !$0.isEmpty }.joined(separator: " | ")
                }()
                let entry = ScanEntry(
                    result: prediction, image: image,
                    patientName:   patientInfo.name,
                    patientAge:    patientInfo.age,
                    patientGender: patientInfo.gender,
                    notes:         combinedNotes
                )
                persistence.save(entry: entry)

                if prediction.severity.shouldCallEmergency {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showEmergencyAlert = true
                    }
                }

            case .failure(let error):
                // 🔊 Haptic Error Feedback
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                
                errorMessage = error.localizedDescription
                showError    = true
            }
        }
    }

    private func triggerEmergencyCheck(result: PredictionResult) {
        if result.severity.shouldCallEmergency { showEmergencyAlert = true }
    }

    private func callEmergency() { callNumber("911") }
    private func callNumber(_ number: String) {
        if let url = URL(string: "tel://\(number)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Result Summary Card
struct ResultSummaryCard: View {
    let result: PredictionResult
    let image: UIImage?
    let onEmergencyTap: () -> Void

    @State private var showDetail = false
    @State private var appear = false

    var guide: DiseaseGuide { DiseaseGuide.guide(for: result.condition, confidence: result.confidence) }

    var body: some View {
        VStack(spacing: 16) {
            // Condition badge
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(result.condition.color.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: result.condition.icon)
                        .font(.system(size: 24))
                        .foregroundColor(result.condition.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.condition.displayName)
                        .font(GAIAFont.heading(20))
                        .foregroundColor(result.condition.color)
                    Text(result.condition.shortDescription)
                        .font(GAIAFont.body(13))
                        .foregroundColor(.gaiaSubtext)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(result.confidence * 100))%")
                        .font(GAIAFont.display(22))
                        .foregroundColor(result.condition.color)
                    Text("confidence")
                        .font(GAIAFont.body(11))
                        .foregroundColor(.gaiaSubtext)
                }
            }

            Divider().background(Color.gaiaBorder)

            // Probability bars
            VStack(spacing: 10) {
                ForEach(DiseaseCondition.allCases, id: \.self) { cond in
                    let prob = result.allProbabilities[cond.rawValue] ?? 0
                    ProbabilityBar(label: cond.displayName, probability: prob, color: cond.color,
                                   isTop: cond == result.condition)
                }
            }

            Divider().background(Color.gaiaBorder)

            // Action buttons
            VStack(spacing: 10) {
                Button {
                    showDetail = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Full Analysis & Guide")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(GAIAFont.caption(15))
                    .foregroundColor(.gaiaCyan)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.gaiaCyan.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gaiaCyan.opacity(0.3), lineWidth: 1))
                }

                if result.severity.shouldCallEmergency {
                    Button(action: onEmergencyTap) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Emergency — Call Now")
                            Spacer()
                            PulsingDot(color: .white)
                        }
                        .font(GAIAFont.caption(15))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(Color.colorTB)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.colorTB.opacity(0.5), radius: 8)
                    }
                }
            }
        }
        .padding(20)
        // 🔊 VoiceOver Grouping Fix
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analysis complete. Diagnosis: \(result.condition.displayName), with \(Int(result.confidence * 100)) percent confidence.")
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gaiaCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(result.condition.color.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: result.condition.color.opacity(0.15), radius: 20)
        )
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appear = true }
        }
        .sheet(isPresented: $showDetail) {
            if let img = image {
                ResultDetailView(result: result, image: img, patientInfo: PatientInfo())
            }
        }
    }
}

// MARK: - Probability Bar
struct ProbabilityBar: View {
    let label:    String
    let probability: Float
    let color:    Color
    let isTop:    Bool
    @State private var width: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(GAIAFont.caption(12))
                .foregroundColor(isTop ? color : .gaiaSubtext)
                .frame(width: 110, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gaiaBorder).frame(height: 8)
                    Capsule()
                        .fill(isTop
                              ? LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [color.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: width * geo.size.width, height: 8)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: width)
                }
            }
            .frame(height: 8)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    width = CGFloat(probability)
                }
            }

            Text(String(format: "%.1f%%", probability * 100))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isTop ? color : .gaiaSubtext)
                .frame(width: 42, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(Int(probability * 100)) percent")
    }
}

// MARK: - Scanning Overlay Animation
struct ScanningOverlay: View {
    @State private var scanY: CGFloat = 0
    @State private var opacity: Double = 0.7
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gaiaCyan.opacity(0.05))

                // Scan line
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.gaiaCyan, .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 3)
                        .blur(radius: 2)
                        .opacity(opacity)
                        .shadow(color: Color.gaiaCyan, radius: 6)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(y: scanY)
            }
            .onAppear {
                // 🛡️ REDUCE MOTION: Freezes the scanning line and fades it instead of sweeping
                if !reduceMotion {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        scanY = geo.size.height
                    }
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        opacity = 0.3
                    }
                } else {
                    scanY = geo.size.height / 2 // Park it in the middle
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        opacity = 0.2
                    }
                }
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        #if targetEnvironment(simulator)
        picker.sourceType = .photoLibrary
        #else
        picker.sourceType = .camera
        #endif
        picker.delegate   = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ p: CameraView) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Patient Info Form
struct PatientInfoForm: View {
    @Binding var patientInfo: PatientInfo
    let onAnalyze: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.gaiaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Patient Information")
                                .font(GAIAFont.heading(22))
                                .foregroundColor(.gaiaText)
                            Text("Optional — helps generate a more complete report")
                                .font(GAIAFont.body(13))
                                .foregroundColor(.gaiaSubtext)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                        Group {
                            InfoField(label: "Patient Name", placeholder: "e.g. John Doe", text: $patientInfo.name)
                            InfoField(label: "Age", placeholder: "e.g. 45", text: $patientInfo.age)
                                .keyboardType(.numberPad)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Gender").font(GAIAFont.caption(14)).foregroundColor(.gaiaSubtext)
                                Picker("Gender", selection: $patientInfo.gender) {
                                    ForEach(["Not Specified", "Male", "Female", "Other"], id: \.self) { Text($0) }
                                }
                                .pickerStyle(.segmented)
                            }

                            InfoField(label: "Doctor's Name", placeholder: "e.g. Dr. Smith", text: $patientInfo.doctorName)
                            InfoField(label: "Notes", placeholder: "Any symptoms or observations...", text: $patientInfo.notes)
                        }

                        VStack(spacing: 12) {
                            CyanButton(title: "Analyze X-Ray", icon: "waveform.path.ecg") {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onAnalyze() }
                            }

                            Button("Skip & Analyze") {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onAnalyze() }
                            }
                            .font(GAIAFont.body(15))
                            .foregroundColor(.gaiaSubtext)
                        }
                        .padding(.top, 8)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct InfoField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(GAIAFont.caption(14)).foregroundColor(.gaiaSubtext)
            TextField(placeholder, text: $text)
                .font(GAIAFont.body(15))
                .foregroundColor(.gaiaText)
                .padding(14)
                .background(Color.gaiaCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gaiaBorder, lineWidth: 1))
        }
    }
}
