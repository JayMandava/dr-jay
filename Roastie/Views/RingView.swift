import SwiftUI

struct RingView: View {
    var progress: Double
    var color: Color
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(1, max(0, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            .frame(width: 84, height: 84)

            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HStack {
        RingView(progress: 0.75, color: DrJayTheme.sleep, icon: "moon.zzz.fill", title: "Sleep", subtitle: "6.2h / 6h")
        RingView(progress: 0.5, color: DrJayTheme.water, icon: "drop.fill", title: "Water", subtitle: "2 / 4 bottles")
    }
    .padding()
}
