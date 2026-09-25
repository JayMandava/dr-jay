import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Binding var settings: AppSettings
    @Binding var appearance: AppAppearance
    @Environment(\.dismiss) private var dismiss
    @State private var healthKitError: String?
    @State private var showResetConfirmation = false
    @State private var isResetting = false
    @State private var showImporter = false
    @State private var showShareSheet = false
    @State private var backupError: String?
    @State private var importResultMessage: String?
    @State private var isImporting = false
    @State private var brainDumpModels = BrainDumpModelManager.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("Water") {
                    Stepper("Daily goal: \(settings.waterGoalBottles) bottles", value: $settings.waterGoalBottles, in: 1...12)
                    Stepper("Bottle size: \(settings.bottleSizeMl) ml", value: $settings.bottleSizeMl, in: 250...1500, step: 250)
                }

                Section("Sleep") {
                    Text("Healthy range is fixed at 6–9 hours.")
                        .foregroundStyle(.secondary)
                    Toggle("Read sleep from Health", isOn: Binding(
                        get: { settings.healthKitEnabled },
                        set: { newValue in
                            if newValue {
                                Task {
                                    do {
                                        try await HealthKitManager.shared.requestAuthorization()
                                        settings.healthKitEnabled = true
                                    } catch {
                                        healthKitError = error.localizedDescription
                                        settings.healthKitEnabled = false
                                    }
                                }
                            } else {
                                settings.healthKitEnabled = false
                            }
                        }
                    ))
                    if let healthKitError {
                        Text(healthKitError).font(.caption).foregroundStyle(.red)
                    }
                }

                Section("Check-in times") {
                    ForEach(CheckInWindow.allCases) { window in
                        Stepper(
                            "\(window.label): \(formattedHour(settings.checkInHours[window] ?? window.defaultHour))",
                            value: Binding(
                                get: { settings.checkInHours[window] ?? window.defaultHour },
                                set: { settings.checkInHours[window] = $0 }
                            ),
                            in: 0...23
                        )
                    }
                }

                Section("Roast intensity") {
                    Picker("Tone", selection: $settings.roastIntensity) {
                        ForEach(RoastIntensity.allCases) { intensity in
                            Text(intensity.label).tag(intensity)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if brainDumpModels.isReady {
                        Picker(
                            "On-device model",
                            selection: Binding(
                                get: { brainDumpModels.selectedProvider },
                                set: { brainDumpModels.select($0) }
                            )
                        ) {
                            ForEach(BrainDumpModelProvider.allCases) { provider in
                                Text(provider.label).tag(provider)
                            }
                        }
                    } else {
                        LabeledContent("On-device model", value: BrainDumpModelProvider.apple.label)
                    }

                    brainDumpModelStatus

                    switch brainDumpModels.state {
                    case .notDownloaded, .failed:
                        Button {
                            brainDumpModels.download()
                        } label: {
                            Label("Download Gemma 4 E2B", systemImage: "arrow.down.circle")
                        }
                    case .ready:
                        Button(role: .destructive) {
                            Task { await brainDumpModels.deleteModel() }
                        } label: {
                            Label("Delete Gemma Model", systemImage: "trash")
                        }
                    case .downloading, .verifying:
                        EmptyView()
                    }
                } header: {
                    Text("Brain Dump")
                } footer: {
                    Text("Apple Intelligence remains the default. Gemma is an optional 2.59 GB download, runs entirely on device, and is excluded from backups. Conversations are never saved.")
                }

                Section {
                    NavigationLink {
                        FoodMemoriesView()
                    } label: {
                        Label("Food Memories", systemImage: "brain.head.profile")
                    }
                } footer: {
                    Text("Corrections teach Dr Jay how to classify the same food next time. Everything stays on device.")
                }

                Section {
                    if let daysRemaining {
                        Label(
                            daysRemaining <= 0
                                ? "Install has expired"
                                : "Expires in \(daysRemaining) day\(daysRemaining == 1 ? "" : "s")",
                            systemImage: "clock.badge.exclamationmark"
                        )
                        .foregroundStyle(daysRemaining <= 2 ? DrJayTheme.roast : Color.secondary)
                    }

                    Button {
                        do {
                            try DayCoordinator.shared.writeBackupNow()
                            backupError = nil
                            showShareSheet = true
                        } catch {
                            AppLogger.report(error, operation: "Prepare backup export", logger: AppLogger.backup)
                            backupError = "Export failed: \(error.localizedDescription)"
                        }
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImporter = true
                    } label: {
                        if isImporting {
                            Label("Importing…", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Import Backup", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(isImporting)

                    if let importResultMessage {
                        Text(importResultMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let backupError {
                        Text(backupError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("A free (non-paid) developer install expires after 7 days. Export a backup before that happens, and import it after reinstalling to keep your history and learned food corrections.")
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Dr Jay", systemImage: "stethoscope")
                            .font(.headline)
                        Text("Sleep, water, food, and a lightweight step check—with clinical honesty and an unhealthy amount of sarcasm.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Private by design", systemImage: "lock.shield")
                            .font(.headline)
                        Text("Roasts, food analysis, and learned corrections stay on device. Health access is read-only. Today's step count is displayed but never stored or exported.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    aboutDetail(
                        "Food score",
                        detail: "Good 80–100 · Bad 60–79 · Ugly 0–59"
                    )

                    aboutDetail(
                        "Daily report",
                        detail: "Food 35% · Sleep 30% · Water 30% · Steps 5%"
                    )

                    Text("Generate a full report anytime from Today. The score uses fixed arithmetic; only Dr Jay’s commentary is written by the on-device model.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LabeledContent("Version", value: appVersion)
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        if isResetting {
                            Label("Resetting…", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Reset App Data", systemImage: "trash")
                        }
                    }
                    .disabled(isResetting)
                } footer: {
                    Text("Erases all logged history, learned food corrections, streaks, and settings, and starts onboarding over. This can't be undone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(DrJayTheme.canvas)
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset all app data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    isResetting = true
                    Task {
                        await brainDumpModels.deleteModel()
                        await DayCoordinator.shared.resetAllData()
                        settings = AppSettings()
                        appearance = .system
                        isResetting = false
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all sleep, water, and food history, learned food corrections, your streak, and every setting. It can't be undone.")
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    isImporting = true
                    Task {
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        do {
                            let count = try await DayCoordinator.shared.importBackup(from: url)
                            importResultMessage = "Imported \(count) day\(count == 1 ? "" : "s") of history."
                        } catch {
                            importResultMessage = "Import failed: \(error.localizedDescription)"
                        }
                        isImporting = false
                    }
                case .failure(let error):
                    importResultMessage = "Import failed: \(error.localizedDescription)"
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityShareSheet(items: [BackupManager.fileURL])
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        SharedStore.save(settings)
                        Task {
                            await DayCoordinator.shared.applyWaterGoalChange(settings.waterGoalBottles)
                            await DayCoordinator.shared.refreshToday()
                        }
                        dismiss()
                    }
                }
            }
            .tint(DrJayTheme.primary)
            .task {
                brainDumpModels.refreshStatus()
            }
        }
        .preferredColorScheme(appearance.colorScheme)
    }

    @ViewBuilder
    private var brainDumpModelStatus: some View {
        switch brainDumpModels.state {
        case .notDownloaded:
            Label("Gemma not downloaded", systemImage: "externaldrive")
                .foregroundStyle(.secondary)
        case .downloading:
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: brainDumpModels.downloadProgress)
                Text("Downloading \(brainDumpModels.downloadProgress.formatted(.percent.precision(.fractionLength(0))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .verifying:
            HStack(spacing: 8) {
                ProgressView()
                Text("Checking integrity and starting LiteRT…")
            }
            .foregroundStyle(.secondary)
        case .ready:
            Label("Gemma verified and ready", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(DrJayTheme.roast)
        }
    }

    private var daysRemaining: Int? {
        guard let expiry = AppConfig.provisioningExpiryDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiry).day ?? 0
        return max(0, days)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return version
        }
        return "\(version) (\(build))"
    }

    private func aboutDetail(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func formattedHour(_ hour: Int) -> String {
        let components = DateComponents(hour: hour)
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
