import SwiftUI
import Combine

@main
struct GAIAApp: App {
    @StateObject private var persistenceManager = PersistenceManager.shared
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(persistenceManager)
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var showSplash = true
    @Published var selectedTab: Int = 0
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                ContentView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity
                    ))
                    .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.9), value: appState.showSplash)
    }
}
