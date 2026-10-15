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
    private enum Field: Hashable { case minutes, note }
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Time well spent")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Kind", selection: $category) {
                            ForEach(PresenceCategory.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(category == .solo
                             ? "Time away from digital distractions, just for yourself."
                             : "Attentive time with someone important. A meaningful phone call counts too.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ForEach([15, 30, 60], id: \.self) { value in
                                Button {
                                    Haptics.tap()
                                    minutes = String(value)
                                } label: {
                                    Text("\(value) min")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        HStack {
                            Text("Minutes")
                            Spacer()
                            TextField("1–1440", text: $minutes)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .minutes)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                                .accessibilityLabel("Minutes")
                        }
                        DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                    }
                    .presenceField()

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Optional note", text: $note, axis: .vertical)
                            .focused($focusedField, equals: .note)
                            .lineLimit(2...4)
                            .onChange(of: note) { _, value in
                                if value.count > 500 { note = String(value.prefix(500)) }
                            }
                        Text("\(note.count)/500")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .presenceField()

                    Label {
                        Text("Saved in history and backups, unlike Brain Dump. Log shared time once, not in both categories.")
                    } icon: {
                        Image(systemName: "lock.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DrJayTheme.canvas.ignoresSafeArea())
            .navigationTitle("Log Presence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
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
        // Presence has more controls than the single-input food/exercise
        // sheets. Give those controls room without returning to full screen.
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.visible)
    }
}

private extension View {
    func presenceField() -> some View {
        padding(16)
            .background(DrJayTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(DrJayTheme.outline.opacity(0.7), lineWidth: 0.5)
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
