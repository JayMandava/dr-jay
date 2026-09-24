import SwiftUI

struct OnboardingView: View {
    @Binding var settings: AppSettings
    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DrJayTheme.surface)
                    .frame(width: 128, height: 128)
                    .overlay {
                        Circle()
                            .strokeBorder(iconColor.opacity(0.28), lineWidth: 1)
                    }
                    .shadow(color: iconColor.opacity(0.12), radius: 24, y: 10)
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .id(step)
            .transition(.scale(scale: 0.85).combined(with: .opacity))

            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 6) {
                ForEach(0..<5) { index in
                    Capsule()
                        .fill(index == step ? iconColor : Color.secondary.opacity(0.25))
                        .frame(width: index == step ? 18 : 6, height: 6)
                }
            }
            .padding(.top, 4)

            Spacer()

            Button(step < 4 ? "Next" : "Let's go") {
                Task { await advance() }
            }
            .buttonStyle(.glassProminent)
            .tint(iconColor)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(DrJayTheme.canvas.ignoresSafeArea())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
    }

    private var icon: String {
        switch step {
        case 0: "stethoscope"
        case 1: "moon.zzz.fill"
        case 2: "drop.fill"
        case 3: "fork.knife"
        default: "bell.badge.fill"
        }
    }

    private var iconColor: Color {
        step == 4 ? DrJayTheme.amber : DrJayTheme.clinicalBlue
    }

    private var title: String {
        switch step {
        case 0: "Meet Dr Jay"
        case 1: "Sleep, checked 3x a day"
        case 2: "Water, checked 3x a day"
        case 3: "Food, judged instantly"
        default: "Stay in the loop"
        }
    }

    private var subtitle: String {
        switch step {
        case 0: "Dr Jay keeps you honest about sleep, water, and food — with private, on-device intelligence and a bedside manner problem."
        case 1: "Every morning, afternoon, and night, Dr Jay checks whether you landed in the healthy 6–9 hour range."
        case 2: "Log a bottle every time you finish one. Dr Jay keeps checking until you hit the full daily goal."
        case 3: "Log what you ate in plain language. Unhealthy choices get an immediate roast, and your day earns a Good, Bad, or Ugly score."
        default: "Allow notifications so Dr Jay can actually check in on you."
        }
    }

    private func advance() async {
        if step < 4 {
            step += 1
            return
        }
        _ = await NotificationManager.requestAuthorization()
        settings.onboardingComplete = true
        SharedStore.save(settings)
        await DayCoordinator.shared.refreshToday()
    }
}
