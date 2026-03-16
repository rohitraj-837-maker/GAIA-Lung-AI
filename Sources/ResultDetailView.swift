import SwiftUI

struct ResultDetailView: View {
    let result: PredictionResult
    let image:  UIImage
    let patientInfo: PatientInfo

    @Environment(\.dismiss) var dismiss
    @State private var selectedSection = 0
    @State private var showEmergency   = false
    @State private var headerAppeared  = false

    private var guide: DiseaseGuide { DiseaseGuide.guide(for: result.condition, confidence: result.confidence) }
    private let sections = ["Overview", "Steps", "Questions", "Precautions"]

    var body: some View {
        ZStack {
            Color.gaiaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Hero Header ──
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [result.condition.color.opacity(0.25), Color.gaiaBackground],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 220)

                    HStack(spacing: 20) {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(result.condition.color.opacity(0.6), lineWidth: 2))
                            .shadow(color: result.condition.color.opacity(0.3), radius: 10)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: result.condition.icon)
                                    .foregroundColor(result.condition.color)
                                // ✅ displayName: "COVID-19" not "Covid"
                                Text(result.condition.displayName)
                                    .font(GAIAFont.heading(22))
                                    .foregroundColor(result.condition.color)
                            }
                            Text("\(Int(result.confidence * 100))% confidence")
                                .font(GAIAFont.body(14)).foregroundColor(.gaiaSubtext)
                            SeverityBadge(level: result.severity)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24).padding(.bottom, 20)
                }
                .overlay(alignment: .topLeading) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.5)).frame(width: 36, height: 36)
                            Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .padding(.top, 56).padding(.leading, 20)
                }

                // ── Section Picker ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<sections.count, id: \.self) { i in
                            Button {
                                withAnimation(.spring(response: 0.35)) { selectedSection = i }
                            } label: {
                                Text(sections[i])
                                    .font(GAIAFont.caption(14))
                                    .foregroundColor(selectedSection == i ? .black : .gaiaSubtext)
                                    .padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(Capsule().fill(selectedSection == i ? result.condition.color : Color.gaiaCard))
                            }
                            .accessibilityLabel(sections[i])
                            .accessibilityAddTraits(selectedSection == i ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                }

                Divider().background(Color.gaiaBorder)

                // ── Section Content ──
                ScrollView(showsIndicators: false) {
                    Group {
                        switch selectedSection {
                        case 0: overviewSection
                        case 1: stepsSection
                        case 2: questionsSection
                        case 3: precautionsSection
                        default: overviewSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }

                if result.severity.shouldCallEmergency { emergencyBanner }
            }
        }
    }

    // MARK: - Overview
    private var overviewSection: some View {
        VStack(spacing: 20) {
            InfoBlock(icon: "brain", title: "AI Reasoning", color: result.condition.color) {
                Text(guide.aiReasoning).font(GAIAFont.body(14)).foregroundColor(.gaiaText).lineSpacing(4)
            }
            InfoBlock(icon: "doc.text.fill", title: "Overview", color: .gaiaAccent) {
                Text(guide.overview).font(GAIAFont.body(14)).foregroundColor(.gaiaText).lineSpacing(4)
            }
            InfoBlock(icon: "waveform.path.ecg.rectangle.fill", title: "X-Ray Findings", color: .gaiaPurple) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(guide.xrayFindings, id: \.self) { finding in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(Color.gaiaPurple).frame(width: 6, height: 6).padding(.top, 5)
                            Text(finding).font(GAIAFont.body(13)).foregroundColor(.gaiaText).lineSpacing(2)
                        }
                    }
                }
            }
            InfoBlock(icon: "map.fill", title: "Affected Regions", color: .colorPneumonia) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(guide.lungRegionsAffected, id: \.self) { region in
                        HStack(spacing: 10) {
                            Image(systemName: "location.fill").font(.system(size: 11)).foregroundColor(.colorPneumonia)
                            Text(region).font(GAIAFont.body(13)).foregroundColor(.gaiaText)
                        }
                    }
                }
            }
            InfoBlock(icon: "waveform.path.ecg", title: "Heatmap Description", color: .gaiaCyan) {
                Text(guide.heatmapDescription).font(GAIAFont.body(14)).foregroundColor(.gaiaText).lineSpacing(4)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Steps
    private var stepsSection: some View {
        VStack(spacing: 16) { ForEach(guide.immediateSteps) { step in StepCard(step: step) } }
            .padding(.top, 16)
    }

    // MARK: - Questions
    private var questionsSection: some View {
        VStack(spacing: 0) {
            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "stethoscope").foregroundColor(.gaiaCyan).font(.system(size: 16))
                        Text("Questions to ask your doctor").font(GAIAFont.heading(15)).foregroundColor(.gaiaText)
                    }
                    Text("Share this list with your physician at your next consultation")
                        .font(GAIAFont.body(12)).foregroundColor(.gaiaSubtext)
                }
            }
            .padding(.top, 16)
            VStack(spacing: 12) {
                ForEach(Array(guide.doctorQuestions.enumerated()), id: \.0) { i, q in
                    QuestionRow(number: i + 1, question: q, color: result.condition.color)
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Precautions
    private var precautionsSection: some View {
        VStack(spacing: 16) {
            GlassCard(padding: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "shield.fill").foregroundColor(.colorNormal).font(.system(size: 20))
                    VStack(alignment: .leading) {
                        Text("Precautions & Home Care").font(GAIAFont.heading(15)).foregroundColor(.gaiaText)
                        Text("Follow these guidelines until you see a doctor").font(GAIAFont.body(12)).foregroundColor(.gaiaSubtext)
                    }
                }
            }
            .padding(.top, 16)
            ForEach(guide.precautions, id: \.self) { p in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.colorNormal).font(.system(size: 18)).padding(.top, 1)
                    Text(p).font(GAIAFont.body(14)).foregroundColor(.gaiaText).lineSpacing(3)
                }
                .padding(14).background(Color.gaiaCard).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            InfoBlock(icon: "exclamationmark.triangle.fill", title: "⚠️ Go to ER Immediately If:", color: .colorTB) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(guide.emergencySignals, id: \.self) { signal in
                        HStack(spacing: 10) {
                            Circle().fill(Color.colorTB).frame(width: 6, height: 6)
                            Text(signal).font(GAIAFont.body(13)).foregroundColor(.gaiaText)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Emergency Banner
    private var emergencyBanner: some View {
        HStack(spacing: 14) {
            PulsingDot(color: .white)
            Text("High severity detected — seek immediate care")
                .font(GAIAFont.caption(14)).foregroundColor(.white)
            Spacer()
            Button("Call 911") { callEmergency() }
                .font(GAIAFont.heading(14)).foregroundColor(.colorTB)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.white).clipShape(Capsule())
                .accessibilityLabel("Call 911 emergency services")
                .accessibilityHint("Dials emergency services immediately")
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(Color.colorTB)
        .alert("Call Emergency Services?", isPresented: $showEmergency) {
            Button("Call 911", role: .destructive) { callEmergency() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func callEmergency() {
        if let url = URL(string: "tel://911") { UIApplication.shared.open(url) }
    }
}

// MARK: - Supporting Views

struct InfoBlock<Content: View>: View {
    let icon: String; let title: String; let color: Color; let content: Content
    init(icon: String, title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon; self.title = title; self.color = color; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(color)
                Text(title).font(GAIAFont.heading(15)).foregroundColor(.gaiaText)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.gaiaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.25), lineWidth: 1))
    }
}

struct StepCard: View {
    let step: DiseaseGuide.ActionStep
    @State private var expanded = false

    var priorityColor: Color {
        switch step.priority {
        case .urgent: return .colorTB
        case .high:   return .colorPneumonia
        case .medium: return .gaiaCyan
        case .low:    return .colorNormal
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.spring()) { expanded.toggle() } } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(priorityColor.opacity(0.15)).frame(width: 44, height: 44)
                        Image(systemName: step.icon).font(.system(size: 18)).foregroundColor(priorityColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title).font(GAIAFont.heading(14)).foregroundColor(.gaiaText)
                        Text(step.priority == .urgent ? "🚨 URGENT" : step.priority == .high ? "⚠️ HIGH PRIORITY" : "Recommended")
                            .font(GAIAFont.body(11)).foregroundColor(priorityColor)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12)).foregroundColor(.gaiaSubtext)
                }
                .padding(16)
            }
            if expanded {
                Text(step.description)
                    .font(GAIAFont.body(13)).foregroundColor(.gaiaText).lineSpacing(3)
                    .padding(.horizontal, 16).padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.gaiaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(priorityColor.opacity(0.3), lineWidth: 1))
    }
}

struct QuestionRow: View {
    let number: Int; let question: String; let color: Color
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 30, height: 30)
                Text("\(number)").font(GAIAFont.heading(13)).foregroundColor(color)
            }
            .padding(.top, 2)
            Text(question).font(GAIAFont.body(14)).foregroundColor(.gaiaText).lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                UIPasteboard.general.string = question
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { copied = false } }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(copied ? .colorNormal : .gaiaSubtext)
            }
        }
        .padding(14).background(Color.gaiaCard).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SeverityBadge: View {
    let level: SeverityLevel
    var body: some View {
        HStack(spacing: 6) {
            if level.shouldCallEmergency { PulsingDot(color: level.color) }
            Text(level.label).font(GAIAFont.caption(12)).foregroundColor(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(level.color.opacity(0.8)).clipShape(Capsule())
    }
}
