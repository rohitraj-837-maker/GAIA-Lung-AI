import SwiftUI

// MARK: - Color Theme
extension Color {
    static let gaiaBackground    = Color(hex: "080C18")
    static let gaiaCard          = Color(hex: "0F1629")
    static let gaiaCardSecondary = Color(hex: "161D35")
    static let gaiaCyan          = Color(hex: "00D4FF")
    static let gaiaPurple        = Color(hex: "7C3AED")
    static let gaiaGlow          = Color(hex: "00A8CC")
    static let gaiaAccent        = Color(hex: "3B82F6")

    // Disease colors
    static let colorNormal    = Color(hex: "10B981")
    static let colorPneumonia = Color(hex: "F59E0B")
    static let colorTB        = Color(hex: "EF4444")
    static let colorCOVID     = Color(hex: "A855F7")

    static let gaiaText          = Color(hex: "E2E8F0")
    static let gaiaSubtext       = Color(hex: "64748B")
    static let gaiaBorder        = Color(hex: "1E293B")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Typography
struct GAIAFont {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func heading(_ size: CGFloat) -> Font  { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat) -> Font     { .system(size: size, weight: .regular, design: .rounded) }
    static func caption(_ size: CGFloat) -> Font  { .system(size: size, weight: .medium, design: .rounded) }
}

// MARK: - Gradient Presets
extension LinearGradient {
    static let gaiaHero = LinearGradient(
        colors: [Color.gaiaCyan.opacity(0.8), Color.gaiaPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let gaiaCard = LinearGradient(
        colors: [Color.gaiaCard, Color.gaiaCardSecondary],
        startPoint: .top,
        endPoint: .bottom
    )
    static func disease(_ condition: DiseaseCondition) -> LinearGradient {
        switch condition {
        case .normal:    return LinearGradient(colors: [Color.colorNormal, Color.colorNormal.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
        case .pneumonia: return LinearGradient(colors: [Color.colorPneumonia, Color.colorPneumonia.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
        case .tb:        return LinearGradient(colors: [Color.colorTB, Color.colorTB.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
        case .covid:     return LinearGradient(colors: [Color.colorCOVID, Color.colorCOVID.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Reusable Components

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 20

    init(padding: CGFloat = 20, cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gaiaCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.gaiaCyan.opacity(0.3), Color.gaiaPurple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

struct CyanButton: View {
    let title: String
    let icon: String
    var gradient: LinearGradient = LinearGradient.gaiaHero
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(GAIAFont.caption(16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.gaiaCyan.opacity(0.3), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - SwiftUI Color → UIColor bridge
extension Color {
    var uiColor: UIColor { UIColor(self) }
}

struct PulsingDot: View {
    let color: Color
    @State private var scale = 1.0
    @State private var opacity = 0.7

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    scale = 1.5
                    opacity = 0.3
                }
            }
    }
}
