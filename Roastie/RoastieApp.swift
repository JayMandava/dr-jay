import SwiftUI
import WidgetKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@main
struct RoastieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = SharedStore.loadSettings()
    @AppStorage(AppConfig.DefaultsKey.appearance, store: AppConfig.sharedDefaults)
    private var appearance: AppAppearance = .system
    @AppStorage(AppConfig.DefaultsKey.theme, store: AppConfig.sharedDefaults)
    private var theme: AppTheme = .tropicTonalities

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.onboardingComplete {
                    TodayView(settings: $settings, appearance: $appearance, theme: $theme)
                } else {
                    OnboardingView(settings: $settings)
                }
            }
            .modelContainer(PersistenceController.modelContainer)
            .preferredColorScheme(appearance.colorScheme)
            .onChange(of: theme) {
                WidgetCenter.shared.reloadAllTimelines()
            }
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
