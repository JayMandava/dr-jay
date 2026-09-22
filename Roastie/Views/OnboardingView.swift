import SwiftUI

struct OnboardingView: View {
    @Binding var settings: AppSettings
    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 128, height: 128)
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
                ForEach(0..<4) { index in
                    Capsule()
                        .fill(index == step ? iconColor : Color.secondary.opacity(0.25))
                        .frame(width: index == step ? 18 : 6, height: 6)
                }
            }
            .padding(.top, 4)

            Spacer()

            Button(step < 3 ? "Next" : "Let's go") {
                Task { await advance() }
            }
            .buttonStyle(.borderedProminent)
            .tint(iconColor)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
    }

    private var icon: String {
        switch step {
        case 0: "stethoscope"
        case 1: "moon.zzz.fill"
        case 2: "drop.fill"
        default: "bell.badge.fill"
        }
    }

    private var iconColor: Color {
        switch step {
        case 0: .indigo
        case 1: .indigo
        case 2: .cyan
        default: .orange
        }
    }

    private var title: String {
        switch step {
        case 0: "Meet Dr Jay"
        case 1: "Sleep, checked 3x a day"
        case 2: "Water, checked 3x a day"
        default: "One more thing"
        }
    }

    private var subtitle: String {
        switch step {
        case 0: "Dr Jay keeps you honest about sleep and water — with an on-device AI that hypes you up when you win and roasts you when you don't."
        case 1: "Every morning, afternoon, and night, Dr Jay checks if you've hit your sleep window. Miss it, and you'll hear about it."
        case 2: "Log a bottle every time you finish one. Fall behind pace and the roast comes for you."
        default: "Allow notifications so Dr Jay can actually check in on you."
        }
    }

    private func advance() async {
        if step < 3 {
            step += 1
            return
        }
        _ = await NotificationManager.requestAuthorization()
        settings.onboardingComplete = true
        SharedStore.save(settings)
        await NotificationManager.rescheduleAll(settings: settings)
        await DayCoordinator.shared.refreshToday()
    }
}
