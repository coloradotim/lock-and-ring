import SwiftUI

@main
struct LockAndRingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: AppViewModel())
        }
        .windowResizability(.contentSize)
    }
}
