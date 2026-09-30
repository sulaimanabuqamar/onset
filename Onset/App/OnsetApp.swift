import SwiftUI

@main
struct OnsetApp: App {
    @StateObject private var store = OnsetStore()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.onboarded {
                    HomeView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(store)
            .environmentObject(purchases)
            .tint(Theme.red)
            .onAppear {
                Narrator.shared.enabled = UserDefaults.standard.object(forKey: "voicePrompts") as? Bool ?? true
                purchases.configure()
            }
        }
    }
}
