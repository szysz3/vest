import SwiftUI
import Factory
import Presentation

@main
struct VestApp: App {
    @StateObject private var lockViewModel = Container.shared.lockViewModel()

    var body: some Scene {
        WindowGroup {
            if lockViewModel.isUnlocked {
                NavigationTabContainer()
            } else {
                LockScreen(viewModel: lockViewModel)
            }
        }
    }
}
