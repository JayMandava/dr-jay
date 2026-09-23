import SwiftUI

@main
struct RoastieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = SharedStore.loadSettings()

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.onboardingComplete {
                    TodayView(settings: $settings)
                } else {
                    OnboardingView(settings: $settings)
                }
            }
            .modelContainer(PersistenceController.modelContainer)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await DayCoordinator.shared.refreshToday()
                appDelegate.scheduleDailyRefresh()
            }
        }
    }
}
