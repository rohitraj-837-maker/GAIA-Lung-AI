import SwiftUI

// MARK: - Keyboard Helper
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

struct ReportView: View {
    @EnvironmentObject var persistence: PersistenceManager

    @State private var selectedEntry:  ScanEntry?
    @State private var patientName     = ""
    @State private var patientAge      = ""
    @State private var patientGender   = "Not Specified"
    @State private var doctorName      = ""
    @State private var notes           = ""
    @State private var isGenerating    = false
    @State private var pdfData:        Data?
    @State private var showShareSheet  = false
    @State private var showEntryPicker = false

    private var canGenerate: Bool { selectedEntry != nil }

    var body: some View {
        NavigationView {
            ZStack {
                Color.gaiaBackground
                    .ignoresSafeArea()
                    .onTapGesture { hideKeyboard() }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        reportHeader
                        scanSelectorCard

                        if selectedEntry != nil {
                            patientInfoForm
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if canGenerate { generateButton }

                        if pdfData != nil {
                            reportReadyCard
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal:   .opacity
                                ))
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { hideKeyboard() }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.gaiaCyan)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showEntryPicker) { ScanPickerSheet(selected: $selectedEntry) }
        .sheet(isPresented: $showShareSheet) {
            if let data = pdfData { SharePDFView(data: data) }
        }
        .onAppear {
            if selectedEntry == nil, let latest = persistence.scanHistory.first {
                selectedEntry = latest
            }
        }
    }

    // MARK: - Header
    private var reportHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generate Report")
                    .font(GAIAFont.display(26))
                    .foregroundStyle(LinearGradient.gaiaHero)
                Text("Export a PDF for your physician")
                    .font(GAIAFont.body(14))
                    .foregroundColor(.gaiaSubtext)
            }
            Spacer()
            ZStack {
                Circle().fill(Color.gaiaCard).frame(width: 48, height: 48)
                Image(systemName: "doc.text.fill").font(.system(size: 20)).foregroundColor(.gaiaCyan)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Scan Selector
    private var scanSelectorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Scan").font(GAIAFont.heading(16)).foregroundColor(.gaiaText)

                if let entry = selectedEntry {
                    HStack(spacing: 14) {
                        if let img = entry.image {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(entry.condition.color.opacity(0.5), lineWidth: 1.5))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            // ✅ displayName: "COVID-19" not "Covid"
                            Text(entry.condition.displayName)
                                .font(GAIAFont.heading(15))
                                .foregroundColor(entry.condition.color)
                            Text("\(Int(entry.confidence * 100))% confidence")
                                .font(GAIAFont.body(12)).foregroundColor(.gaiaSubtext)
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(GAIAFont.body(11)).foregroundColor(.gaiaSubtext)
                        }
                        Spacer()
                        Button { showEntryPicker = true } label: {
                            Text("Change")
                                .font(GAIAFont.caption(13)).foregroundColor(.gaiaCyan)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.gaiaCyan.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                } else {
                    Button { showEntryPicker = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundColor(.gaiaCyan)
                            Text("Choose from Scan History").font(GAIAFont.caption(15)).foregroundColor(.gaiaText)
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

    // MARK: - Patient Info Form
    private var patientInfoForm: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Patient Information").font(GAIAFont.heading(16)).foregroundColor(.gaiaText)

                InfoField(label: "Patient Name",    placeholder: "Full name",            text: $patientName)
                InfoField(label: "Age",             placeholder: "Years",                text: $patientAge).keyboardType(.numberPad)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender").font(GAIAFont.caption(13)).foregroundColor(.gaiaSubtext)
                    Picker("", selection: $patientGender) {
                        ForEach(["Not Specified", "Male", "Female", "Other"], id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                InfoField(label: "Referring Doctor", placeholder: "Dr. Name",           text: $doctorName)
                InfoField(label: "Clinical Notes",   placeholder: "Symptoms, history…", text: $notes)
            }
        }
        .onAppear {
            if let entry = selectedEntry {
                if !entry.patientName.isEmpty   { patientName   = entry.patientName }
                if !entry.patientAge.isEmpty    { patientAge    = entry.patientAge }
                if !entry.patientGender.isEmpty { patientGender = entry.patientGender }
                if !entry.notes.isEmpty         { notes         = entry.notes }
            }
        }
    }

    // MARK: - Generate Button
    private var generateButton: some View {
        CyanButton(
            title: isGenerating ? "Generating PDF..." : "Generate Medical Report",
            icon:  isGenerating ? "hourglass"         : "doc.badge.plus"
        ) {
            hideKeyboard()
            generateReport()
        }
        .disabled(isGenerating)
        .opacity(isGenerating ? 0.6 : 1)
    }

    // MARK: - Report Ready Card
    private var reportReadyCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.colorNormal.opacity(0.15)).frame(width: 80, height: 80)
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 38)).foregroundColor(.colorNormal)
                }
                Text("Report Ready!").font(GAIAFont.heading(20)).foregroundColor(.gaiaText)
                Text("Your medical report includes AI analysis, doctor questions, precautions, and personalised recommendations.")
                    .font(GAIAFont.body(13)).foregroundColor(.gaiaSubtext)
                    .multilineTextAlignment(.center).lineSpacing(3)

                VStack(spacing: 12) {
                    CyanButton(title: "Share / Save PDF", icon: "square.and.arrow.up") { showShareSheet = true }
                    Button { pdfData = nil } label: {
                        Text("Generate Another").font(GAIAFont.body(14)).foregroundColor(.gaiaSubtext)
                    }
                }
            }
        }
    }

    // MARK: - Generate
    private func generateReport() {
        guard let entry = selectedEntry else { return }
        isGenerating = true

        let updatedEntry = ScanEntry(
            result: PredictionResult(condition:        entry.condition,
                                     confidence:       entry.confidence,
                                     allProbabilities: entry.probabilities,
                                     timestamp:        entry.timestamp),
            image:         entry.image ?? UIImage(),
            patientName:   patientName.isEmpty   ? entry.patientName   : patientName,
            patientAge:    patientAge.isEmpty     ? entry.patientAge    : patientAge,
            patientGender: patientGender,
            notes: {
                // Merge doctor name into notes (same pattern as ScanView)
                let doc  = doctorName.isEmpty ? "" : "Dr: \(doctorName)"
                let note = notes.isEmpty ? entry.notes : notes
                return [doc, note].filter { !$0.isEmpty }.joined(separator: " | ")
            }()
        )
        let guide = DiseaseGuide.guide(for: entry.condition, confidence: entry.confidence)
        DispatchQueue.global(qos: .userInitiated).async {
            let data = PDFReportGenerator.generate(entry: updatedEntry, guide: guide)
            DispatchQueue.main.async {
                withAnimation(.spring()) { pdfData = data; isGenerating = false }
            }
        }
    }
}

// MARK: - Scan Picker Sheet
struct ScanPickerSheet: View {
    @EnvironmentObject var persistence: PersistenceManager
    @Binding var selected: ScanEntry?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.gaiaBackground.ignoresSafeArea()
                if persistence.scanHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.xmark").font(.system(size: 48)).foregroundColor(.gaiaSubtext)
                        Text("No scans yet").font(GAIAFont.heading(16)).foregroundColor(.gaiaSubtext)
                        Text("Complete a scan first to generate reports").font(GAIAFont.body(13)).foregroundColor(.gaiaSubtext)
                    }
                } else {
                    List(persistence.scanHistory) { entry in
                        Button {
                            selected = entry
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                if let img = entry.image {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    // ✅ displayName: "COVID-19" not "Covid"
                                    Text(entry.condition.displayName)
                                        .font(GAIAFont.heading(14))
                                        .foregroundColor(entry.condition.color)
                                    Text("\(Int(entry.confidence * 100))% confidence")
                                        .font(GAIAFont.body(12)).foregroundColor(.gaiaSubtext)
                                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(GAIAFont.body(11)).foregroundColor(.gaiaSubtext)
                                }
                                Spacer()
                                if selected?.id == entry.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.gaiaCyan)
                                }
                            }
                        }
                        .listRowBackground(Color.gaiaCard)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Select Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.gaiaCyan)
                }
            }
        }
    }
}

// MARK: - Share PDF
struct SharePDFView: UIViewControllerRepresentable {
    let data: Data
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GAIA_Report.pdf")
        try? data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
