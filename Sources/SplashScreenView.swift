import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject var appState: AppState

    // ── Logo ──
    @State private var logoScale:   CGFloat = 0.85
    @State private var logoOpacity: Double  = 0
    @State private var logoBlur:    CGFloat = 24
    @State private var ringTrim:    CGFloat = 0

    // ── ECG ──
    @State private var ecgTrim:    CGFloat = 0
    @State private var ecgOpacity: Double  = 0

    // ── Title ──
    @State private var titleOpacity: Double  = 0
    @State private var titleOffset:  CGFloat = 12

    // ── Progress ──
    @State private var arcTrim:     CGFloat = 0
    @State private var arcOpacity:  Double  = 0
    @State private var statusIndex: Int     = 0
    @State private var dotPhase:    Int     = 0

    // ── Footer ──
    @State private var footerOpacity: Double = 0

    // ── Exit ──
    @State private var exitScale:   CGFloat = 1.0
    @State private var exitOpacity: Double  = 1.0

    private let statuses = [
        "Initializing neural network",
        "Loading model weights",
        "Calibrating classifiers",
        "Ready"
    ]

    var body: some View {
        ZStack {
            Color.gaiaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                logoView
                    .padding(.bottom, 32)

                wordmarkView
                    .padding(.bottom, 52)

                ecgView
                    .padding(.bottom, 52)

                progressView

                Spacer()

                Text("Powered by Apple Create ML")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.gaiaSubtext.opacity(0.45))
                    .opacity(footerOpacity)
                    .padding(.bottom, 44)
            }
        }
        .scaleEffect(exitScale)
        .opacity(exitOpacity)
        .onAppear { runSequence() }
    }

    // MARK: - Logo
    private var logoView: some View {
        ZStack {
            // Static inner ring — gives depth
            Circle()
                .strokeBorder(Color.gaiaBorder.opacity(0.5), lineWidth: 1)
                .frame(width: 132, height: 132)

            // Animated draw-on outer ring
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(
                    LinearGradient(
                        colors: [Color.gaiaCyan, Color.gaiaPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: 156, height: 156)
                .rotationEffect(.degrees(-90))

            // Core fill
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.gaiaCyan.opacity(0.15), Color.gaiaBackground],
                        center: .center,
                        startRadius: 0,
                        endRadius: 66
                    )
                )
                .frame(width: 130, height: 130)

            // Lung icon
            Image(systemName: "lungs.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.gaiaCyan, Color.gaiaPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.gaiaCyan.opacity(0.5), radius: 18)
        }
        .scaleEffect(logoScale)
        .opacity(logoOpacity)
        .blur(radius: logoBlur)
    }

    // MARK: - Wordmark
    private var wordmarkView: some View {
        VStack(spacing: 8) {
            Text("GAIA")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.gaiaCyan, Color.gaiaPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.gaiaCyan.opacity(0.25), radius: 20, y: 4)

            Text("LUNG INTELLIGENCE AI")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(.gaiaSubtext)
                .tracking(5.5)
        }
        .opacity(titleOpacity)
        .offset(y: titleOffset)
    }

    // MARK: - ECG
    private var ecgView: some View {
        ECGShape()
            .trim(from: 0, to: ecgTrim)
            .stroke(
                LinearGradient(
                    colors: [Color.gaiaCyan.opacity(0.9), Color.gaiaCyan.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 210, height: 38)
            .opacity(ecgOpacity)
    }

    // MARK: - Progress + Status
    private var progressView: some View {
        VStack(spacing: 16) {
            // Circular arc
            ZStack {
                Circle()
                    .strokeBorder(Color.gaiaBorder, lineWidth: 2)
                    .frame(width: 46, height: 46)

                Circle()
                    .trim(from: 0, to: arcTrim)
                    .stroke(
                        LinearGradient(
                            colors: [Color.gaiaCyan, Color.gaiaPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 46, height: 46)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: arcTrim)

                Text("\(Int(arcTrim * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gaiaCyan)
            }

            // Status line with trailing dots
            HStack(spacing: 0) {
                Text(statuses[min(statusIndex, statuses.count - 1)])
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.gaiaSubtext)

                Text(String(repeating: ".", count: dotPhase + 1))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.gaiaCyan.opacity(0.6))
                    .frame(width: 18, alignment: .leading)
                    .animation(nil, value: dotPhase)
            }
            .id(statusIndex)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 5)),
                removal:   .opacity
            ))
        }
        .opacity(arcOpacity)
    }

    // MARK: - Sequence
    private func runSequence() {

        // t = 0.0 — logo blooms from blur
        withAnimation(.spring(response: 0.8, dampingFraction: 0.72)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.65)) {
            logoBlur = 0
        }

        // t = 0.5 — outer ring draws on
        after(0.5) {
            withAnimation(.easeOut(duration: 0.65)) {
                ringTrim = 1.0
            }
        }

        // t = 0.9 — title rises in
        after(0.9) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                titleOpacity = 1.0
                titleOffset  = 0
            }
        }

        // t = 1.3 — ECG traces left to right
        after(1.3) {
            withAnimation(.easeIn(duration: 0.1))  { ecgOpacity = 1 }
            withAnimation(.easeInOut(duration: 0.75)) { ecgTrim = 1.0 }
        }

        // t = 1.7 — progress area fades in, arc steps through
        after(1.7) {
            withAnimation(.easeOut(duration: 0.3)) { arcOpacity = 1 }
            startDots()
            stepProgress()
        }

        // t = 1.85 — footer
        after(1.85) {
            withAnimation(.easeIn(duration: 0.5)) { footerOpacity = 1 }
        }

        // t = 3.3 — exit: scale down + fade out
        after(3.3) {
            withAnimation(.easeInOut(duration: 0.6)) {
                exitOpacity = 0
                exitScale   = 0.96
            }
            after(0.55) { appState.showSplash = false }
        }
    }

    private func stepProgress() {
        let count = statuses.count
        for i in 0..<count {
            after(Double(i) * 0.38) {
                withAnimation(.spring(response: 0.3)) {
                    statusIndex = i
                    arcTrim = CGFloat(i + 1) / CGFloat(count)
                }
            }
        }
    }

    private func startDots() {
        var ticks = 0
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { timer in
            dotPhase = (dotPhase + 1) % 3
            ticks += 1
            if ticks > 14 { timer.invalidate() }
        }
    }

    private func after(_ s: Double, block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: block)
    }
}

// MARK: - ECG Waveform Shape
struct ECGShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        // Normalised (x, y) control points for one QRS cycle
        let pts: [(CGFloat, CGFloat)] = [
            (0.00, 0.50),
            (0.10, 0.50),
            (0.17, 0.36),  // P wave up
            (0.24, 0.50),  // P wave down
            (0.30, 0.50),  // PR segment
            (0.35, 0.64),  // Q dip
            (0.41, 0.04),  // R peak
            (0.47, 0.78),  // S nadir
            (0.53, 0.50),  // ST segment
            (0.61, 0.32),  // T wave
            (0.70, 0.50),
            (1.00, 0.50),  // trailing baseline
        ]

        var path = Path()
        path.move(to: CGPoint(x: pts[0].0 * w, y: pts[0].1 * h))

        // Straight lines for the sharp QRS complex, smooth curves elsewhere
        let sharp: Set<Int> = [5, 6, 7, 8]

        for i in 1..<pts.count {
            let cur = CGPoint(x: pts[i].0 * w,   y: pts[i].1 * h)
            if sharp.contains(i) {
                path.addLine(to: cur)
            } else {
                let prev = CGPoint(x: pts[i-1].0 * w, y: pts[i-1].1 * h)
                path.addQuadCurve(to: cur, control: CGPoint(x: (prev.x + cur.x) / 2, y: prev.y))
            }
        }
        return path
    }
}

// MARK: - Preview
struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
            .environmentObject(AppState())
    }
}
