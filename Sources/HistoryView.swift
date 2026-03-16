import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var persistence: PersistenceManager

    @State private var selectedEntry:    ScanEntry?
    @State private var filterCondition:  DiseaseCondition?
    @State private var showDeleteAlert   = false
    @State private var showClearAlert    = false          // confirmation for Clear All
    @State private var entryToDelete:    ScanEntry?
    @State private var searchText        = ""

    private var filteredHistory: [ScanEntry] {
        persistence.scanHistory.filter { entry in
            let matchesFilter = filterCondition == nil || entry.condition == filterCondition
            let matchesSearch = searchText.isEmpty ||
                // Search both the display name AND rawValue so "covid" and "COVID-19" both match
                entry.condition.displayName.localizedCaseInsensitiveContains(searchText) ||
                entry.condition.rawValue.localizedCaseInsensitiveContains(searchText)    ||
                entry.patientName.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.gaiaBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    historyHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gaiaSubtext)
                        TextField("Search scans...", text: $searchText)
                            .font(GAIAFont.body(15))
                            .foregroundColor(.gaiaText)
                    }
                    .padding(12)
                    .background(Color.gaiaCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.gaiaBorder, lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    filterBar

                    if !persistence.scanHistory.isEmpty {
                        statsRow.padding(.horizontal, 20).padding(.bottom, 4)
                        scanTrendChart.padding(.horizontal, 20).padding(.bottom, 8)
                    }

                    Divider().background(Color.gaiaBorder)

                    if filteredHistory.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredHistory) { entry in
                                    HistoryCard(entry: entry) { selectedEntry = entry }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                entryToDelete  = entry
                                                showDeleteAlert = true
                                            } label: { Label("Delete", systemImage: "trash") }
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedEntry) { entry in HistoryDetailView(entry: entry) }
        .alert("Delete Scan?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let e = entryToDelete { persistence.delete(entry: e) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This scan will be permanently removed from history.")
        }
        .alert("Clear All Scans?", isPresented: $showClearAlert) {
            Button("Clear All", role: .destructive) { persistence.clearAll() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all \(persistence.scanHistory.count) scans. This cannot be undone.")
        }
    }

    // MARK: - Header
    private var historyHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Scan History")
                    .font(GAIAFont.display(26))
                    .foregroundStyle(LinearGradient.gaiaHero)
                Text("\(persistence.scanHistory.count) total scans")
                    .font(GAIAFont.body(14))
                    .foregroundColor(.gaiaSubtext)
            }
            Spacer()
            if !persistence.scanHistory.isEmpty {
                Button { showClearAlert = true } label: {
                    Text("Clear All")
                        .font(GAIAFont.caption(13))
                        .foregroundColor(.colorTB)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.colorTB.opacity(0.1))
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Clear all scan history")
                .accessibilityHint("Shows confirmation before deleting all scans")
            }
        }
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", color: .gaiaCyan, selected: filterCondition == nil) {
                    withAnimation { filterCondition = nil }
                }
                ForEach(DiseaseCondition.allCases, id: \.self) { cond in
                    // ✅ shortLabel: "COVID-19", "Normal", "TB", "Pneumonia"
                    filterChip(label: cond.shortLabel, color: cond.color, selected: filterCondition == cond) {
                        withAnimation { filterCondition = filterCondition == cond ? nil : cond }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(label: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(GAIAFont.caption(13))
                .foregroundColor(selected ? .black : .gaiaSubtext)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? color : Color.gaiaCard)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Stats Row
    // Only renders conditions that have at least one scan — avoids a row of zeroes.
    private var statsRow: some View {
        let counts = Dictionary(grouping: persistence.scanHistory, by: \.condition).mapValues(\.count)
        let active = DiseaseCondition.allCases.filter { (counts[$0] ?? 0) > 0 }
        return HStack(spacing: 12) {
            ForEach(active, id: \.self) { cond in
                VStack(spacing: 2) {
                    Text("\(counts[cond] ?? 0)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(cond.color)
                    Text(cond.shortLabel)
                        .font(GAIAFont.body(9))
                        .foregroundColor(.gaiaSubtext)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(cond.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(counts[cond] ?? 0) \(cond.displayName) scans")
            }
        }
    }

    // MARK: - Scan Trend Chart
    // Uses Swift Charts to plot scan count per day over the last 14 days.
    private var scanTrendChart: some View {
        let calendar  = Calendar.current
        let today     = calendar.startOfDay(for: Date())
        let days      = (0..<14).map { calendar.date(byAdding: .day, value: -$0, to: today)! }.reversed()

        struct DayPoint: Identifiable {
            let id = UUID()
            let date: Date
            let count: Int
            let condition: DiseaseCondition
        }

        var points: [DayPoint] = []
        for day in days {
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            for cond in DiseaseCondition.allCases {
                let count = persistence.scanHistory.filter {
                    $0.condition == cond && $0.timestamp >= day && $0.timestamp < next
                }.count
                if count > 0 { points.append(DayPoint(date: day, count: count, condition: cond)) }
            }
        }

        return GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 13)).foregroundColor(.gaiaCyan)
                    Text("14-Day Scan Trend")
                        .font(GAIAFont.heading(14)).foregroundColor(.gaiaText)
                }

                if points.isEmpty {
                    Text("Scans older than 14 days aren't shown here")
                        .font(GAIAFont.body(11)).foregroundColor(.gaiaSubtext)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    Chart(points) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Scans", point.count)
                        )
                        .foregroundStyle(point.condition.color)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated),
                                           centered: true)
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(Color.gaiaSubtext)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                            AxisValueLabel()
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(Color.gaiaSubtext)
                        }
                    }
                    .frame(height: 90)
                    .accessibilityLabel("Scan trend bar chart for the last 14 days")
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: filterCondition == nil ? "clock.badge.xmark" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 52))
                .foregroundColor(.gaiaSubtext)
            // ✅ displayName: "COVID-19" not "Covid"
            Text(filterCondition == nil ? "No scans yet" : "No \(filterCondition!.displayName) scans")
                .font(GAIAFont.heading(18))
                .foregroundColor(.gaiaSubtext)
            Text("Complete a scan on the Scan tab to see results here")
                .font(GAIAFont.body(14))
                .foregroundColor(.gaiaSubtext.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - History Card
struct HistoryCard: View {
    let entry:  ScanEntry
    let onTap:  () -> Void
    @State private var appeared = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    if let img = entry.image {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(entry.condition.color.opacity(0.6), lineWidth: 2))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(entry.condition.color.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: entry.condition.icon)
                            .font(.system(size: 28))
                            .foregroundColor(entry.condition.color)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        // ✅ displayName: "COVID-19" not "Covid"
                        Text(entry.condition.displayName)
                            .font(GAIAFont.heading(15))
                            .foregroundColor(entry.condition.color)
                        SeverityBadge(level: PredictionResult(
                            condition:        entry.condition,
                            confidence:       entry.confidence,
                            allProbabilities: entry.probabilities,
                            timestamp:        entry.timestamp
                        ).severity)
                    }

                    if !entry.patientName.isEmpty {
                        Text(entry.patientName)
                            .font(GAIAFont.body(13))
                            .foregroundColor(.gaiaText)
                    }

                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(GAIAFont.body(12))
                        .foregroundColor(.gaiaSubtext)

                    // Mini probability bars — lookup uses rawValue (correct key in dict)
                    HStack(spacing: 4) {
                        ForEach(DiseaseCondition.allCases, id: \.self) { cond in
                            let p = entry.probabilities[cond.rawValue] ?? 0
                            Capsule()
                                .fill(cond.color.opacity(cond == entry.condition ? 1 : 0.3))
                                .frame(width: CGFloat(p) * 40, height: 4)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(entry.confidence * 100))%")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(entry.condition.color)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.gaiaSubtext)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gaiaCard)
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(entry.condition.color.opacity(0.2), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.condition.displayName), \(Int(entry.confidence * 100))% confidence\(entry.patientName.isEmpty ? "" : ", \(entry.patientName)")")
        .accessibilityHint("Tap to view full analysis")
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.4)) { appeared = true } }
    }
}

// MARK: - History Detail View
struct HistoryDetailView: View {
    let entry: ScanEntry
    @Environment(\.dismiss) var dismiss
    @State private var pdfData:        Data?
    @State private var showShare       = false
    @State private var selectedSection = 0

    private var result: PredictionResult {
        PredictionResult(condition: entry.condition, confidence: entry.confidence,
                         allProbabilities: entry.probabilities, timestamp: entry.timestamp)
    }
    private var guide: DiseaseGuide {
        DiseaseGuide.guide(for: entry.condition, confidence: entry.confidence)
    }
    private let sections = ["Overview", "Steps", "Questions", "Precautions"]

    var body: some View {
        ZStack {
            Color.gaiaBackground.ignoresSafeArea()
            VStack(spacing: 0) {

                // ── Hero ──
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [entry.condition.color.opacity(0.25), Color.gaiaBackground],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 210)

                    HStack(spacing: 20) {
                        if let img = entry.image {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(entry.condition.color.opacity(0.6), lineWidth: 2))
                                .shadow(color: entry.condition.color.opacity(0.3), radius: 10)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: entry.condition.icon)
                                    .foregroundColor(entry.condition.color)
                                // ✅ displayName
                                Text(entry.condition.displayName)
                                    .font(GAIAFont.heading(22))
                                    .foregroundColor(entry.condition.color)
                            }
                            Text("\(Int(entry.confidence * 100))% confidence")
                                .font(GAIAFont.body(14)).foregroundColor(.gaiaSubtext)
                            SeverityBadge(level: result.severity)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
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

                // ── Probability Bars ──
                VStack(spacing: 8) {
                    ForEach(DiseaseCondition.allCases, id: \.self) { cond in
                        let prob = result.allProbabilities[cond.rawValue] ?? 0
                        // ✅ display uses displayName, lookup uses rawValue
                        ProbabilityBar(label: cond.displayName, probability: prob,
                                       color: cond.color, isTop: cond == result.condition)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.gaiaCard)

                // ── Section Tabs ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<sections.count, id: \.self) { i in
                            Button {
                                withAnimation(.spring(response: 0.3)) { selectedSection = i }
                            } label: {
                                Text(sections[i])
                                    .font(GAIAFont.caption(14))
                                    .foregroundColor(selectedSection == i ? .black : .gaiaSubtext)
                                    .padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(Capsule().fill(selectedSection == i ? entry.condition.color : Color.gaiaCard))
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }

                Divider().background(Color.gaiaBorder)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
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

                        CyanButton(title: "Generate Report PDF", icon: "doc.badge.plus") {
                            let g = guide
                            DispatchQueue.global(qos: .userInitiated).async {
                                let data = PDFReportGenerator.generate(entry: entry, guide: g)
                                DispatchQueue.main.async { pdfData = data; showShare = true }
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let data = pdfData { SharePDFView(data: data) }
        }
    }

    private var overviewSection: some View {
        VStack(spacing: 16) {
            if !entry.patientName.isEmpty || !entry.patientAge.isEmpty {
                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Patient Information").font(GAIAFont.heading(15)).foregroundColor(.gaiaText)
                        if !entry.patientName.isEmpty   { infoRow("Name",   entry.patientName) }
                        if !entry.patientAge.isEmpty    { infoRow("Age",    entry.patientAge) }
                        if !entry.patientGender.isEmpty { infoRow("Gender", entry.patientGender) }
                        if !entry.notes.isEmpty         { infoRow("Notes",  entry.notes) }
                    }
                }
            }
            InfoBlock(icon: "brain", title: "AI Reasoning", color: entry.condition.color) {
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
        }
        .padding(.top, 16)
    }

    private var stepsSection: some View {
        VStack(spacing: 16) { ForEach(guide.immediateSteps) { step in StepCard(step: step) } }
            .padding(.top, 16)
    }

    private var questionsSection: some View {
        VStack(spacing: 12) {
            GlassCard(padding: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "stethoscope").foregroundColor(.gaiaCyan).font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Questions to ask your doctor").font(GAIAFont.heading(15)).foregroundColor(.gaiaText)
                        Text("Share this list at your next consultation").font(GAIAFont.body(12)).foregroundColor(.gaiaSubtext)
                    }
                }
            }
            .padding(.top, 16)
            ForEach(Array(guide.doctorQuestions.enumerated()), id: \.0) { i, q in
                QuestionRow(number: i + 1, question: q, color: entry.condition.color)
            }
        }
    }

    private var precautionsSection: some View {
        VStack(spacing: 12) {
            GlassCard(padding: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "shield.fill").foregroundColor(.colorNormal).font(.system(size: 20))
                    VStack(alignment: .leading) {
                        Text("Precautions & Home Care").font(GAIAFont.heading(15)).foregroundColor(.gaiaText)
                        Text("Follow until you see a doctor").font(GAIAFont.body(12)).foregroundColor(.gaiaSubtext)
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

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(GAIAFont.caption(13)).foregroundColor(.gaiaSubtext).frame(width: 70, alignment: .leading)
            Text(value).font(GAIAFont.body(13)).foregroundColor(.gaiaText)
        }
    }
}
