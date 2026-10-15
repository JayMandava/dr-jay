import SwiftUI

struct PresenceCard: View {
    let summary: PresenceSummary
    var title = "Presence today"
    var onLog: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: "leaf")
                    .font(.headline)
                Spacer()
                if let onLog {
                    Button(action: onLog) {
                        Label("Log Time", systemImage: "clock")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(DrJayTheme.primary)
                }
            }
            if summary.isEmpty {
                Text("Make room for yourself or someone important. Log it if you like.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(PresenceCategory.allCases) { category in
                    let minutes = summary.minutes(for: category)
                    if minutes > 0 {
                        HStack(alignment: .firstTextBaseline) {
                            Label(category.label, systemImage: category.symbol)
                            Spacer()
                            Text("\(minutes) min").monospacedDigit().bold()
                        }
                        .font(.subheadline)
                    }
                }
                if let commentary = summary.commentary {
                    Text("Dr Jay: \(commentary)")
                        .font(.subheadline)
                }
            }
            Text("Optional · No score or streak")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .clinicalCard()
    }
}

struct LogPresenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category: PresenceCategory = .solo
    @State private var minutes = "30"
    @State private var date = Date()
    @State private var note = ""
    @State private var saveError = false

    private var duration: Int? {
        guard let value = Int(minutes), (1...1440).contains(value) else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time well spent") {
                    Picker("Kind", selection: $category) {
                        ForEach(PresenceCategory.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    Text(category == .solo
                         ? "Intentional time away from digital distractions: reading, walking, hobbies, or simply being."
                         : "Attentive time with family, friends, or someone important. A meaningful phone call counts too.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        ForEach([15, 30, 60], id: \.self) { value in
                            Button("\(value) min") {
                                Haptics.tap()
                                minutes = String(value)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    TextField("Minutes (1–1440)", text: $minutes)
                        .keyboardType(.numberPad)
                    DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                }
                Section {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                        .onChange(of: note) { _, value in
                            if value.count > 500 { note = String(value.prefix(500)) }
                        }
                    Text("\(note.count)/500")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Saved locally in history and JSON backups. Unlike Brain Dump, these notes persist. Log shared time once, not in both categories.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(DrJayTheme.canvas)
            .navigationTitle("Log Presence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let duration else { return }
                        if DayCoordinator.shared.logPresence(category: category, minutes: duration, date: date, note: note) {
                            dismiss()
                        } else {
                            saveError = true
                        }
                    }
                    .disabled(duration == nil)
                }
            }
            .alert("Couldn’t save Presence", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check the duration and date, and keep the day's combined total within 1,440 minutes. If these are correct, please try saving again.")
            }
            .tint(DrJayTheme.primary)
        }
    }
}

struct PresenceEntryRow: View {
    let entry: PresenceEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Label(entry.category.label, systemImage: entry.category.symbol)
                Spacer()
                Text("\(entry.minutes) min").monospacedDigit()
            }
            .font(.subheadline.weight(.medium))
            if !entry.note.isEmpty {
                Text(entry.note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
