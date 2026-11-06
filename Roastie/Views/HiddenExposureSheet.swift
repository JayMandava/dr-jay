import SwiftUI
import SwiftData

/// No visible navigation entry: only exact Brain Dump commands open this ledger.
struct HiddenExposureSheet: View {
    let initialKind: ExposureKind
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @State private var kind: ExposureKind = .alcohol
    @State private var quantity = "1"
    @State private var note = ""
    @State private var date = Date()
    @State private var editing: ExposureEntry?
    @State private var busy = false
    @State private var saveError = false
    @FocusState private var quantityFocused: Bool

    private var selectedLog: DailyLog? { logs.first { $0.dayKey == date.dayKey } }
    private var entries: [ExposureEntry] { selectedLog?.exposureEntries ?? [] }
    private var summary: ExposureSummary { ExposureSummary(entries: entries) }
    private var count: Double? {
        guard let value = Double(quantity.replacingOccurrences(of: ",", with: ".")), value.isFinite else { return nil }
        guard kind == .alcohol ? (0.5...1000).contains(value)
            : ((1...1000).contains(value) && value.rounded(.down) == value) else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Off the record? Nice try.", systemImage: "eye.slash")
                            .font(.headline)
                        Text("You found the cupboard. Dr Jay found the receipts.")
                            .font(.subheadline)
                    }

                    Picker("Kind", selection: $kind) {
                        ForEach(ExposureKind.allCases) { item in
                            Label(item.label, systemImage: item.symbol).tag(item)
                        }
                    }.pickerStyle(.segmented)

                    Text(kind == .alcohol
                         ? "One UK unit is 10 ml of pure alcohol: volume in ml × strength (ABV %) ÷ 1,000. Spirits, beer and wine all count. For example, 25 ml of spirits at 40% is 1 unit, and 500 ml of beer at 5% is 2.5 units. Log from 0.5 units."
                         : "Count each cigarette, rounding partial ones up. Vaping and other tobacco products aren’t counted. Even one is harmful.")
                        .font(.caption).foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(kind.unit.prefix(1).uppercased() + kind.unit.dropFirst())
                            Spacer()
                            TextField(kind == .alcohol ? "0.5–1,000" : "1–1,000", text: $quantity)
                                .keyboardType(.decimalPad)
                                .focused($quantityFocused)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                                .accessibilityLabel(kind.unit)
                        }
                        if editing == nil {
                            DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                            Text("Pick an earlier day to review, correct or delete its entries.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Correcting an entry for \(date.formatted(date: .abbreviated, time: .omitted)).")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Cancel Correction") { resetEditor() }
                                .buttonStyle(.bordered)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .ledgerField()

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Optional note", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .onChange(of: note) { _, value in
                                if value.count > 500 { note = String(value.prefix(500)) }
                            }
                        Text("\(note.count)/500")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .ledgerField()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("No diplomatic immunity").font(.headline)
                        if summary.isEmpty {
                            Text("No entries for this day. The cupboard can stay closed.")
                                .font(.subheadline)
                        } else {
                            Text(summary.detail.replacingOccurrences(of: "Score −", with: "Score\u{00A0}−"))
                                .font(.subheadline.weight(.semibold))
                            Text(summary.roast).font(.subheadline)
                        }
                        Text("Alcohol costs 8 points per UK unit, plus 12 more for each unit above 2 in a day. Each cigarette costs 20 points. Deductions total at most 100, and the score never drops below 0. Two units is a warning threshold, not a safe allowance, and no amount of alcohol or tobacco is risk-free. This is an accountability score, not a medical one.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.ledgerCard()

                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Receipts · \(date.formatted(date: .abbreviated, time: .omitted))").font(.headline)
                            ForEach(entries.sorted { $0.timestamp > $1.timestamp }) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("\(entry.quantity.formatted(.number.precision(.fractionLength(0...3)))) \(entry.kind.unit(for: entry.quantity))", systemImage: entry.kind.symbol)
                                        .font(.subheadline.weight(.medium))
                                    if let note = entry.note, !note.isEmpty {
                                        Text(note).font(.caption).foregroundStyle(.secondary)
                                    }
                                    HStack {
                                        Button("Correct") {
                                            editing = entry
                                            kind = entry.kind
                                            quantity = String(entry.quantity)
                                            note = entry.note ?? ""
                                        }
                                        Spacer()
                                        Button("Delete", role: .destructive) { delete(entry) }
                                    }.font(.caption)
                                }
                                .disabled(busy)
                                Divider()
                            }
                            Text("To remove a mistake, delete the entry instead of logging zero.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.ledgerCard()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DrJayTheme.canvas.ignoresSafeArea())
            .navigationTitle("Log \(kind.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { quantityFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(count == nil || busy)
                }
            }
            .alert("Couldn’t save entry", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Use 0.5–1,000 alcohol units or 1–1,000 whole cigarettes, with a day up to today, then try again.")
            }
            .onAppear { kind = initialKind }
            .tint(DrJayTheme.primary)
        }
        .overlay {
            if scenePhase != .active {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill").font(.largeTitle)
                    Text("Case file hidden").font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DrJayTheme.canvas)
                .ignoresSafeArea()
            }
        }
        .privacySensitive()
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let count, !busy else { return }
        busy = true
        quantityFocused = false
        let entry = ExposureEntry(id: editing?.id ?? UUID(), kind: kind, quantity: count,
                                  timestamp: editing?.timestamp ?? date,
                                  note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        let key = date.dayKey
        Task {
            if await DayCoordinator.shared.saveExposure(entry, dayKey: key) {
                resetEditor()
                Haptics.tap()
                dismiss()
            } else { saveError = true }
            busy = false
        }
    }

    private func delete(_ entry: ExposureEntry) {
        guard !busy else { return }
        busy = true
        let key = date.dayKey
        Task {
            if await DayCoordinator.shared.deleteExposure(id: entry.id, dayKey: key) {
                if editing?.id == entry.id { resetEditor() }
            } else { saveError = true }
            busy = false
        }
    }

    private func resetEditor() {
        editing = nil
        quantity = "1"
        note = ""
    }
}

private extension View {
    func ledgerCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .clinicalCard()
    }

    /// Same field surface as the Presence sheet.
    func ledgerField() -> some View {
        padding(16)
            .background(DrJayTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(DrJayTheme.outline.opacity(0.7), lineWidth: 0.5)
            }
    }
}
