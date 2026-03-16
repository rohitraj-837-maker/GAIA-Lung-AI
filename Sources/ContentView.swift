import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var tabBarVisible = true

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch appState.selectedTab {
                case 0: ScanView()
                case 1: ReportView()
                case 2: HeatmapTabView()
                case 3: HistoryView()
                case 4: AboutView()
                default: ScanView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gaiaBackground)

            // Custom Tab Bar
            CustomTabBar(selectedTab: $appState.selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String)] = [
        ("waveform.path.ecg.rectangle.fill", "Scan"),
        ("doc.text.fill",                    "Report"),
        ("map.fill",                         "Heatmap"),
        ("clock.fill",                       "History"),
        ("info.circle.fill",                 "About")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { i in
                TabBarItem(
                    icon:       tabs[i].icon,
                    label:      tabs[i].label,
                    isSelected: selectedTab == i,
                    index:      i
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = i
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            ZStack {
                Color.gaiaCard
                    .overlay(
                        LinearGradient(
                            colors: [Color.gaiaCyan.opacity(0.05), Color.gaiaPurple.opacity(0.05)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gaiaCyan.opacity(0.4), Color.gaiaPurple.opacity(0.3)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        )
        .clipShape(
            RoundedCorner(radius: 28, corners: [.topLeft, .topRight])
        )
        .shadow(color: Color.gaiaCyan.opacity(0.1), radius: 20, y: -4)
    }
}

struct TabBarItem: View {
    let icon:       String
    let label:      String
    let isSelected: Bool
    let index:      Int
    let action:     () -> Void

    @State private var bounce = false

    var body: some View {
        Button(action: {
            bounce = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { bounce = false }
        }) {
            VStack(spacing: 5) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(LinearGradient.gaiaHero.opacity(0.2))
                            .frame(width: 48, height: 32)
                    }

                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 22 : 20, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(
                            isSelected
                                ? LinearGradient.gaiaHero
                                : LinearGradient(colors: [Color.gaiaSubtext], startPoint: .top, endPoint: .bottom)
                        )
                        .scaleEffect(bounce ? 0.85 : 1.0)
                        .animation(.spring(response: 0.2), value: bounce)
                }
                .frame(width: 48, height: 32)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .gaiaCyan : .gaiaSubtext)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Rounded Corner Helper
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
