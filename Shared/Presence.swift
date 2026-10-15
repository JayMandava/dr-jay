import Foundation

enum PresenceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case solo, together

    var id: Self { self }
    var label: String { self == .solo ? "Unplugged — solo" : "Time together" }
    var symbol: String { self == .solo ? "leaf" : "person.2" }
}

struct PresenceEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var category: PresenceCategory
    var minutes: Int
    var timestamp: Date
    var note: String
}

/// Descriptive only: no score, target, streak, or inference from missing logs.
struct PresenceSummary {
    let entries: [PresenceEntry]

    var soloMinutes: Int { minutes(for: .solo) }
    var togetherMinutes: Int { minutes(for: .together) }
    var isEmpty: Bool { entries.isEmpty }
    var detail: String {
        var parts: [String] = []
        if soloMinutes > 0 { parts.append("\(soloMinutes) min unplugged — solo") }
        if togetherMinutes > 0 { parts.append("\(togetherMinutes) min together") }
        return parts.joined(separator: " · ")
    }

    var commentary: String? {
        guard let latest = entries.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
        // Presence is always Gentle, regardless of the global intensity.
        let target: RoastTarget = latest.category == .solo ? .presenceSolo : .presenceTogether
        let first = RoastStyleContract.fallback(target: target, intensity: .gentle)
        return RoastStyleContract.fallback(
            target: target, intensity: .gentle,
            excluding: entries.count.isMultiple(of: 2) ? first : nil
        )
    }

    func minutes(for category: PresenceCategory) -> Int {
        entries.filter { $0.category == category && (1...1440).contains($0.minutes) }
            .reduce(0) { $0 + $1.minutes }
    }
}
