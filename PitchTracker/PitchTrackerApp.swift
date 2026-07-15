import SwiftUI

@main
struct PitchTrackerApp: App {
    @StateObject private var store = PitchStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
