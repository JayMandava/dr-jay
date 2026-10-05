import SwiftData
import SwiftUI

struct InsightsView: View {
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    let intensity: RoastIntensity
    let foodRoastsEnabled: Bool

    @State private var period: InsightsPeriod = .sevenDays
    @State private var commentary = ""
    @State private var isGenerating = false
    @State private var commentaryModels = BrainDumpModelManager.shared

    private var report: LongitudinalInsightReport {
        LongitudinalInsightsCalculator.calculate(logs: logs, period: period)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Analysis window", selection: $period) {
                    ForEach(InsightsPeriod.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                coverageCard
                commentaryCard

                ForEach(report.metrics) { metric in
                    metricCard(metric)
                }

                exposureCard

                if let association = report.association {
                    Label(association, systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .clinicalCard()
                }

                Label(
                    "Steps are excluded because Dr Jay does not store historical step totals.",
                    systemImage: "figure.walk"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .background(DrJayTheme.canvas.ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .tint(DrJayTheme.primary)
        .task(id: report.factSummary) {
            await generateCommentary()
        }
    }

    private var coverageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Coverage", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                Text(report.coverageText)
                    .font(.subheadline.weight(.semibold))
            }
            ProgressView(value: Double(report.trackedDays), total: Double(period.rawValue))
                .tint(DrJayTheme.primary)
            Text("\(report.completeDays) complete core day\(report.completeDays == 1 ? "" : "s") · trends need at least 7 logged days in both windows")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .clinicalCard()
    }

    private var commentaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Dr Jay’s analysis", systemImage: "brain.head.profile")
                    .font(.headline)
                Spacer()
                if isGenerating {
                    ProgressView()
                }
            }
            Text(commentary.isEmpty ? "Reading the chart…" : commentary)
                .font(.body)
                .foregroundStyle(commentary.isEmpty ? .secondary : .primary)
            if report.hasMinimumData {
                Button("Regenerate") {
                    Task { await generateCommentary() }
                }
                .font(.caption.weight(.semibold))
                .disabled(isGenerating)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .clinicalCard()
    }

    private func metricCard(_ metric: InsightMetric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.title)
                    .font(.headline)
                Spacer()
                Text(metric.value)
                    .font(.title2.bold().monospacedDigit())
            }
            if let score = metric.score {
                ProgressView(value: score, total: 100)
                    .tint(metricColor(metric))
            }
            HStack {
                Text(metric.detail)
                Spacer()
                Label(metric.direction.label, systemImage: metric.direction.symbol)
                    .foregroundStyle(metricColor(metric))
            }
            .font(.caption)
        }
        .padding(16)
        .clinicalCard()
    }

    private var exposureCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                exposureMetric(
                    value: report.exposureDays > 0 ? "\(report.caffeineTotal)" : "—",
                    label: "Caffeine",
                    icon: "cup.and.saucer.fill",
                    color: DrJayTheme.muted
                )
                Divider()
                    .frame(height: 48)
                exposureMetric(
                    value: report.exposureDays > 0 ? "\(report.sugaryItemTotal)" : "—",
                    label: "Sugary items",
                    icon: "birthday.cake.fill",
                    color: DrJayTheme.roast
                )
            }
            Text(report.exposureDays > 0 ? "Confirmed across \(report.exposureDays) logged food days" : "No confirmed exposure baseline")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .clinicalCard()
    }

    private func exposureMetric(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Label(value, systemImage: icon)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricColor(_ metric: InsightMetric) -> Color {
        switch metric.direction {
        case .improving: DrJayTheme.primary
        case .slipping: DrJayTheme.roast
        case .steady, .buildingBaseline, .context: DrJayTheme.muted
        }
    }

    private func generateCommentary() async {
        guard !isGenerating else { return }
        isGenerating = true
        let previousCommentary = commentary
        commentary = await InsightsNarrativeGenerator.generate(
            report: report,
            intensity: intensity,
            foodRoastsEnabled: foodRoastsEnabled,
            provider: commentaryModels.selectedProvider,
            previousCommentary: previousCommentary
        )
        isGenerating = false
    }
}
