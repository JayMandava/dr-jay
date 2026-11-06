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
                    VStack(alignment: .leading, spacing: 10) {
                        Label("The unofficial case file", systemImage: "eye.slash")
                            .font(.headline)
                        Text("You found the cupboard. Dr Jay found the receipts.")
                            .font(.subheadline)
                        Text("Saved to daily logs and backups. Closing Brain Dump does not erase these entries. Score effects also appear in reports and notifications.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.ledgerCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Kind", selection: $kind) {
                            ForEach(ExposureKind.allCases) { item in
                                Label(item.label, systemImage: item.symbol).tag(item)
                            }
                        }.pickerStyle(.segmented)
                        Text(kind == .alcohol ? "One UK unit = 10ml pure alcohol: volume in ml × ABV% ÷ 1,000. A 25ml spirit at 40% is 1 unit; 500ml beer at 5% is 2.5 units. Log fractional units from 0.5; use the formula for your pour. A glass is not a unit." : "Count cigarettes, including partial cigarettes rounded up. This counter does not measure vaping or other tobacco products. Even one is harmful.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text(kind.unit)
                            Spacer()
                            TextField(kind == .alcohol ? "0.5–1000" : "1–1000", text: $quantity)
                                .keyboardType(.decimalPad)
                                .focused($quantityFocused)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                                .accessibilityLabel(kind.unit)
                        }
                        TextField("Optional note", text: $note, axis: .vertical)
                            .lineLimit(1...3)
                            .onChange(of: note) { _, value in
                                if value.count > 500 { note = String(value.prefix(500)) }
                            }
                        if editing == nil {
                            DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                        } else {
                            Text("Correcting an entry for \(date.formatted(date: .abbreviated, time: .omitted)).")
                                .font(.caption)
                        }
                        Button(editing == nil ? "File the evidence" : "Save correction") { save() }
                            .buttonStyle(.borderedProminent)
                            .disabled(count == nil || busy)
                        if editing != nil {
                            Button("Cancel correction") { resetEditor() }
                        }
                    }.ledgerCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("No diplomatic immunity").font(.headline)
                        if summary.isEmpty {
                            Text("No entries for this day. The cupboard can stay closed.")
                        } else {
                            Text(summary.detail).font(.subheadline.weight(.semibold))
                            Text(summary.roast).font(.subheadline)
                        }
                        Text("Alcohol costs 8 points per UK unit, plus 12 extra per unit above 2 in a day. Smoke costs 20 points per cigarette from the first. The alcohol deduction rounds to the nearest point. Combined deduction caps at 100; score floors at 0. Two units is an escalation trigger, not a safe allowance. No amount is risk-free. This is an accountability policy, not a clinical risk score. Roast: always high here.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.ledgerCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Receipts · \(date.formatted(date: .abbreviated, time: .omitted))").font(.headline)
                        ForEach(entries.sorted { $0.timestamp > $1.timestamp }) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                Label("\(entry.quantity.formatted(.number.precision(.fractionLength(0...3)))) \(entry.kind.unit)", systemImage: entry.kind.symbol)
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
                        if entries.isEmpty { Text("No receipts.").foregroundStyle(.secondary) }
                        Text("Choose any past day above to correct or delete its entries. Zero means no entry; delete an incorrect receipt rather than logging zero.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.ledgerCard()
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DrJayTheme.canvas.ignoresSafeArea())
            .navigationTitle("Off the record? Nice try.")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { quantityFocused = false }
                }
            }
            .alert("Couldn’t save the receipt", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Use 0.5–1,000 alcohol units or 1–1,000 whole cigarettes and a day up to today, then try again.")
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
        .presentationDetents([.large])
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
}
