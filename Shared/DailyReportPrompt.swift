import Foundation

/// Only app-authored variation cues may cross the model boundary. Prior reports
/// can contain deleted ledger entries and remain exclusively in local comparisons.
enum DailyReportPrompt {
    enum ComicAngle: String, CaseIterable {
        case bureaucraticFailure = "bureaucratic failure"
        case clinicalAbsurdity = "clinical absurdity"
        case failedCompetence = "failed competence"
        case caseFileEmbarrassment = "case-file embarrassment"
    }

    static func variation(angle: ComicAngle? = nil) -> String {
        let cue = angle ?? ComicAngle.allCases.randomElement() ?? .clinicalAbsurdity
        return "Optional comic angle: \(cue.rawValue). Write one fresh roast sentence."
    }
}
