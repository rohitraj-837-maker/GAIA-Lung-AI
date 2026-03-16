import SwiftUI

struct AboutView: View {
    @State private var pulseOrb  = false
    @State private var showFull  = [false, false, false, false, false]
    @State private var showDisclaimer = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.gaiaBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // App Hero
                        appHeroSection

                        // Disclaimer banner
                        disclaimerBanner

                        // Model specs
                        modelSpecsCard

                        // Disease classes
                        diseasesCard

                        // How it works
                        howItWorksCard

                        // Credits
                        creditsCard

                        // Emergency notice
                        emergencyCard

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showDisclaimer) {
            FullDisclaimerView()
        }
    }

    // Renders the animated orb logo and version badges at the top of the page.
    private var appHeroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Animated orb background
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(LinearGradient.gaiaHero.opacity(0.15 - Double(i) * 0.04))
                        .frame(width: CGFloat(100 + i * 30))
                        .scaleEffect(pulseOrb ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(Double(i) * 0.4), value: pulseOrb)
                }

                Image(systemName: "lungs.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LinearGradient.gaiaHero)
                    .shadow(color: Color.gaiaCyan.opacity(0.6), radius: 14)
            }
            .frame(height: 120)
            .onAppear { pulseOrb = true }

            Text("GAIA Lung AI")
                .font(GAIAFont.display(32))
                .foregroundStyle(LinearGradient.gaiaHero)

            Text("Chest X-Ray Intelligence")
                .font(GAIAFont.caption(15))
                .foregroundColor(.gaiaSubtext)
                .tracking(3)

            HStack(spacing: 20) {
                versionBadge("v21.0", icon: "tag.fill", color: .gaiaCyan)
                versionBadge("EfficientNet B3", icon: "apple.logo", color: .gaiaPurple)
                versionBadge("4 Classes", icon: "chart.pie.fill", color: .colorNormal)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func versionBadge(_ label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12))
            Text(label).font(GAIAFont.caption(12))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
    }

    // Tappable banner that opens the full medical disclaimer sheet.
    private var disclaimerBanner: some View {
        Button { showDisclaimer = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.colorPneumonia.opacity(0.2)).frame(width: 40, height: 40)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.colorPneumonia)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Medical Disclaimer")
                        .font(GAIAFont.heading(14))
                        .foregroundColor(.colorPneumonia)
                    Text("This AI may make mistakes. Tap to read full disclaimer.")
                        .font(GAIAFont.body(12))
                        .foregroundColor(.gaiaSubtext)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gaiaSubtext)
                    .font(.system(size: 13))
            }
            .padding(16)
            .background(Color.colorPneumonia.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.colorPneumonia.opacity(0.4), lineWidth: 1))
        }
    }

    // Displays key training and architecture details for the embedded CoreML model.
    private var modelSpecsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("About the Model", icon: "cpu.fill", color: .gaiaCyan)

                specRow("Framework",      "EfficientNet B3",         icon: "apple.logo")
                specRow("Architecture",   "Image Classifier CNN",    icon: "network")
                specRow("Training Images","~20,000 images",            icon: "photo.stack.fill")
                specRow("Version",        "GAIA_Final v21.0",         icon: "tag.fill")
                specRow("Input Size",     "224×224 pixels",          icon: "square.fill")
                specRow("Classes",        "4 (Normal, Pneumonia, TB, COVID-19)", icon: "list.bullet")
                specRow("Inference",      "On-device (CoreML)",      icon: "iphone")
                specRow("Privacy",        "No data leaves your device", icon: "lock.shield.fill")

                Divider().background(Color.gaiaBorder)

                Text("⚠️ Training Limitation")
                    .font(GAIAFont.heading(13))
                    .foregroundColor(.colorPneumonia)
                Text("This model was trained on approximately 20,000 images across four disease categories. While substantially larger than a prototype dataset, real clinical-grade AI models are validated on millions of diverse, annotated images. This app remains a demonstration and educational tool only.")
                    .font(GAIAFont.body(13))
                    .foregroundColor(.gaiaText)
                    .lineSpacing(3)
            }
        }
    }

    private func specRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.gaiaCyan)
                .frame(width: 20)
            Text(label)
                .font(GAIAFont.caption(13))
                .foregroundColor(.gaiaSubtext)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(GAIAFont.body(13))
                .foregroundColor(.gaiaText)
                .lineLimit(2)
            Spacer()
        }
    }

    // Disease Classes
    private var diseasesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Detectable Conditions", icon: "lungs.fill", color: .gaiaPurple)

                ForEach(DiseaseCondition.allCases, id: \.self) { cond in
                    DiseaseInfoRow(condition: cond)
                }
            }
        }
    }

    private var howItWorksCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("How GAIA Works", icon: "gearshape.2.fill", color: .gaiaAccent)

                ForEach(Array(steps.enumerated()), id: \.0) { i, step in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(Color.gaiaAccent.opacity(0.15)).frame(width: 32, height: 32)
                            Text("\(i + 1)").font(GAIAFont.heading(14)).foregroundColor(.gaiaAccent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title).font(GAIAFont.heading(14)).foregroundColor(.gaiaText)
                            Text(step.desc).font(GAIAFont.body(12)).foregroundColor(.gaiaSubtext).lineSpacing(2)
                        }
                    }
                }
            }
        }
    }

    private let steps: [(title: String, desc: String)] = [
        ("Upload X-Ray", "Select a chest PA X-ray image from your photo library or camera"),
        ("Preprocessing", "Image is resized to 224×224 and normalized for the CoreML model"),
        ("Neural Network Inference", "GAIA_Final CNN classifies the image across 4 disease categories"),
        ("Confidence Scoring", "Softmax probabilities are computed for all 4 classes"),
        ("Guide Generation", "Disease-specific advice, questions, and precautions are generated"),
        ("Heatmap Visualization", "Grid-based activation mapping highlights key X-ray regions")
    ]

    // MARK: - Credits
    private var creditsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Technology Stack", icon: "star.fill", color: .colorNormal)

                creditRow("SwiftUI",     "User Interface Framework",   "apple.logo")
                creditRow("Core ML",     "On-Device Machine Learning", "cpu.fill")
                creditRow("Vision",      "Image Analysis Framework",   "eye.fill")
                creditRow("PDFKit",      "Report Generation",          "doc.fill")
                creditRow("PhotosUI",    "Image Picker Integration",   "photo.fill")
                creditRow("Apple Create ML", "Model Training Platform", "wand.and.stars")
            }
        }
    }

    private func creditRow(_ name: String, _ role: String, _ icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(.colorNormal).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(GAIAFont.caption(13)).foregroundColor(.gaiaText)
                Text(role).font(GAIAFont.body(11)).foregroundColor(.gaiaSubtext)
            }
        }
    }

    // MARK: - Emergency Card
    private var emergencyCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "phone.fill").font(.system(size: 20)).foregroundColor(.white)
                VStack(alignment: .leading) {
                    Text("Emergency Numbers").font(GAIAFont.heading(15)).foregroundColor(.white)
                    Text("Tap to call if you need immediate help").font(GAIAFont.body(12)).foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                emergencyButton("🇺🇸 911", number: "911")
                emergencyButton("🇬🇧 999", number: "999")
                emergencyButton("🇪🇺 112", number: "112")
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color.colorTB, Color.colorTB.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.colorTB.opacity(0.3), radius: 16)
    }

    private func emergencyButton(_ label: String, number: String) -> some View {
        Button {
            if let url = URL(string: "tel://\(number)") { UIApplication.shared.open(url) }
        } label: {
            Text(label)
                .font(GAIAFont.heading(14))
                .foregroundColor(.colorTB)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel("Call \(label) emergency services")
    }

    // MARK: - Helpers
    private func sectionTitle(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            Text(title).font(GAIAFont.heading(17)).foregroundColor(.gaiaText)
        }
    }
}

// MARK: - Disease Info Row
struct DiseaseInfoRow: View {
    let condition: DiseaseCondition
    @State private var expanded = false

    private var description: String {
        switch condition {
        case .normal:    return "Healthy lung fields with no pathological changes. Normal aeration and vascular markings throughout."
        case .pneumonia: return "Bacterial or viral infection causing alveolar consolidation. Typically presents as lobar or bronchopneumonic opacities."
        case .tb:        return "Mycobacterium tuberculosis infection preferentially affecting upper lung lobes. May show cavities, fibrosis, or calcified granulomas."
        case .covid:     return "SARS-CoV-2 viral pneumonitis with bilateral peripheral ground glass opacities and consolidation in lower lobes."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.spring()) { expanded.toggle() } } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(condition.color.opacity(0.15)).frame(width: 38, height: 38)
                        Image(systemName: condition.icon).font(.system(size: 17)).foregroundColor(condition.color)
                    }
                    Text(condition.displayName).font(GAIAFont.heading(14)).foregroundColor(.gaiaText)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12)).foregroundColor(.gaiaSubtext)
                }
                .padding(.vertical, 6)
            }
            if expanded {
                Text(description)
                    .font(GAIAFont.body(13))
                    .foregroundColor(.gaiaSubtext)
                    .lineSpacing(3)
                    .padding(.leading, 50)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Full Disclaimer View
struct FullDisclaimerView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.gaiaBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Medical Disclaimer")
                            .font(GAIAFont.display(24))
                            .foregroundStyle(LinearGradient.gaiaHero)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(.gaiaSubtext)
                        }
                    }
                    .padding(.top, 20)

                    disclaimerBlock(
                        icon: "⚠️",
                        title: "NOT a Medical Device",
                        text: "GAIA Lung AI is NOT a certified medical device and has NOT been approved by the FDA, CE, or any other regulatory authority. It must not be used as a substitute for professional medical diagnosis, advice, or treatment."
                    )

                    disclaimerBlock(
                        icon: "🔬",
                        title: "Training Data Limitation",
                        text: "This AI model was trained on approximately 20,000 chest X-ray images. While this is a meaningful dataset size, clinical AI tools are validated on millions of diverse, annotated images from real hospital populations. The model's real-world accuracy, sensitivity, and specificity have not been independently validated."
                    )

                    disclaimerBlock(
                        icon: "👨‍⚕️",
                        title: "Consult a Doctor",
                        text: "Always consult a licensed physician, radiologist, or healthcare professional for any medical concerns. Do not make treatment decisions based on this app's output."
                    )

                    disclaimerBlock(
                        icon: "🔒",
                        title: "Privacy",
                        text: "All image analysis occurs entirely on your device using Apple's CoreML framework. No images or medical data are transmitted to any server or third party."
                    )

                    disclaimerBlock(
                        icon: "⚡",
                        title: "Emergency",
                        text: "If you believe you are experiencing a medical emergency, call your local emergency number (911, 999, 112) immediately. Do not rely on this app during emergencies."
                    )

                    disclaimerBlock(
                        icon: "📱",
                        title: "App Store Notice",
                        text: "This application is provided for educational and informational purposes only. The developers make no warranties, express or implied, regarding the accuracy, completeness, or fitness for any particular purpose of this application."
                    )

                    Text("By using GAIA Lung AI, you acknowledge and accept these limitations and agree that the developers are not liable for any decisions made based on this app's outputs.")
                        .font(GAIAFont.body(13))
                        .foregroundColor(.gaiaSubtext)
                        .lineSpacing(3)
                        .padding(.vertical, 8)

                    Button {
                        dismiss()
                    } label: {
                        Text("I Understand")
                            .font(GAIAFont.heading(16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient.gaiaHero)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func disclaimerBlock(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(icon).font(.system(size: 20))
                Text(title).font(GAIAFont.heading(15)).foregroundColor(.gaiaText)
            }
            Text(text)
                .font(GAIAFont.body(13))
                .foregroundColor(.gaiaSubtext)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Color.gaiaCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
