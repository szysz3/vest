import SwiftUI
import Factory
import Presentation

@main
struct VestApp: App {
    @StateObject private var lockViewModel = Container.shared.lockViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if lockViewModel.isUnlocked {
                    NavigationTabContainer()
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                } else {
                    LockScreen(viewModel: lockViewModel)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: lockViewModel.isUnlocked)
        }
    }
}
