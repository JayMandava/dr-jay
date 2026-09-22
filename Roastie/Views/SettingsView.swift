import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Binding var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var healthKitError: String?
    @State private var showResetConfirmation = false
    @State private var isResetting = false
    @State private var showImporter = false
    @State private var importResultMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Water") {
                    Stepper("Daily goal: \(settings.waterGoalBottles) bottles", value: $settings.waterGoalBottles, in: 1...12)
                    Stepper("Bottle size: \(settings.bottleSizeMl) ml", value: $settings.bottleSizeMl, in: 250...1500, step: 250)
                }

                Section("Sleep") {
                    Text("Goal is fixed at 6 hours.")
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
                    if let daysRemaining {
                        Label(
                            daysRemaining <= 0
                                ? "Install has expired"
                                : "Expires in \(daysRemaining) day\(daysRemaining == 1 ? "" : "s")",
                            systemImage: "clock.badge.exclamationmark"
                        )
                        .foregroundStyle(daysRemaining <= 2 ? .orange : .secondary)
                    }

                    ShareLink(item: BackupManager.fileURL) {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        DayCoordinator.shared.writeBackupNow()
                    })

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
                } header: {
                    Text("Data")
                } footer: {
                    Text("A free (non-paid) developer install expires after 7 days. Export a backup before that happens, and import it after reinstalling to keep your history.")
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
                    Text("Erases all logged history, streaks, and settings, and starts onboarding over. This can't be undone.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset all app data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    isResetting = true
                    Task {
                        await DayCoordinator.shared.resetAllData()
                        settings = AppSettings()
                        isResetting = false
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all sleep and water history, your streak, and every setting. It can't be undone.")
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        SharedStore.save(settings)
                        Task {
                            await NotificationManager.rescheduleAll(settings: settings)
                            await DayCoordinator.shared.applyWaterGoalChange(settings.waterGoalBottles)
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private var daysRemaining: Int? {
        guard let expiry = AppConfig.provisioningExpiryDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiry).day ?? 0
        return max(0, days)
    }

    private func formattedHour(_ hour: Int) -> String {
        let components = DateComponents(hour: hour)
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
