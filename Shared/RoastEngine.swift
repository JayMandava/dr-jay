import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct NudgeContext: Sendable {
    var kind: CheckKind
    var window: CheckInWindow
    var met: Bool
    /// Human-readable specifics, e.g. "slept 4.5h of a 6h goal" or "2 of 4 bottles logged".
    var detail: String
    /// Raw value/goal pair (hours slept, or bottles logged) — used to detect
    /// a genuine overachievement so the prompt can force an unambiguous win
    /// instead of the model hedging a "met" outcome into sounding like a roast.
    var value: Double
    var goal: Double
    var streak: Int
    var intensity: RoastIntensity

    var isOversleeping: Bool {
        kind == .sleep && value > AppConfig.sleepGoalMaxHours
    }
}

struct NudgeMessage: Sendable, Codable {
    var text: String
}

/// Generates the roast (goal missed) or hype (goal met) line for a check-in.
/// Runs entirely on-device via Apple's Foundation Models framework when
/// available (Apple Intelligence enabled, eligible device/region); otherwise
/// falls back to a curated local line bank so the app always has something
/// to say, offline, on every device.
///
/// Voice: a brilliant, misanthropic diagnostician — dry, clinical, deadpan.
/// No slang, no emoji, no cheerleading. Just a doctor reading your chart and
/// not particularly impressed by what it says.
enum RoastEngine {

    static func generate(_ context: NudgeContext) async -> NudgeMessage {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let generated = await generateOnDevice(context) {
                return generated
            }
        }
        #endif
        return fallback(context)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generateOnDevice(_ context: NudgeContext) async -> NudgeMessage? {
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        let session = LanguageModelSession(instructions: instructions(for: context))

        do {
            let response = try await session.respond(
                to: prompt(for: context),
                generating: GeneratedNudge.self
            )
            let text = sanitize(response.content.text)
            guard !text.isEmpty else { return nil }
            return NudgeMessage(text: text)
        } catch {
            return nil
        }
    }

    @available(iOS 26.0, *)
    private static func instructions(for context: NudgeContext) -> String {
        let persona: String
        switch context.intensity {
        case .gentle:
            persona = "You are Dr. Gregory House (House, M.D.), dialed down: brilliant, weary, quietly sarcastic — but not cruel. You state uncomfortable truths plainly, like reading a chart out loud, without the usual contempt for the patient."
        case .playful:
            persona = "You are Dr. Gregory House (House, M.D.): a brilliant, misanthropic diagnostician with a sharp, dry wit and zero patience for excuses. You don't do encouragement, you do diagnoses. Everyone is an idiot, including the patient — that patient is the user. Clinical detachment mixed with a cutting one-liner."
        case .spicy:
            persona = "You are Dr. Gregory House (House, M.D.) at his most insufferable: brilliant, ruthless, and treating every missed goal like a patient lying about their symptoms. Cutting, clinical, thoroughly unimpressed, convinced everyone (especially the patient) is an idiot — but the insight always lands."
        }
        return """
        \(persona)
        You write exactly one short reaction to the user's sleep or water tracking, in House's voice: the diagnostician who's smarter than everyone in the room and never lets anyone forget it.
        Rules:
        - Second person ("you"), present tense.
        - One or two sentences, under 140 characters total.
        - No hashtags, no quotation marks, no emoji, no slang like "bro" or "champ."
        - Dry and clinical, not chipper. Think diagnosis, not pep talk.
        - Reference the specific numbers given exactly as provided, as numerals (e.g. "7", never "seven").
        - Use correct grammar and punctuation throughout — proper capitalization, commas where a sentence needs one, no run-ons or sentence fragments.
        - Output ONLY the reaction itself. Nothing before or after it: no labels, no restated numbers, no trailing tokens of any kind.
        - The line must end with exactly one terminal punctuation mark (a period, "!", or "?") and absolutely nothing after it — no stray digits, no extra words, no second punctuation mark.
        - If the goal was met, acknowledge it with clinical approval, nothing gushing. If missed, deliver the diagnosis and move on.
        - If the goal was MET, the line must read as unambiguously positive. Never hedge a win with words like "but," "however," "questionable," or "acceptable" — those contradict the outcome and confuse the reader. A clean win reads as a clean win, dry wit and all.
        - Sleep can be missed two opposite ways: too little, or too much. Read the context carefully for which one applies before writing — the joke is different for each.
        """
    }

    @available(iOS 26.0, *)
    private static func prompt(for context: NudgeContext) -> String {
        let outcome = context.met ? "The user MET this goal." : "The user MISSED this goal."
        let streakLine = context.streak > 1 ? "They're on a \(context.streak)-day streak of hitting both goals." : ""
        let overachievement = context.goal > 0 ? context.value / context.goal : 1
        let overshootLine = (context.met && overachievement >= 1.5)
            ? "They didn't just meet this, they blew past it — \(context.kind == .water ? "more than double the bottle goal" : "well over the sleep goal"). This must read as a clean, unambiguous win. No qualifiers."
            : ""
        let oversleepLine = context.isOversleeping
            ? "This is NOT undersleeping — they slept too much (over \(Int(AppConfig.sleepGoalMaxHours))h). The diagnosis is oversleeping, not exhaustion. Roast the excess, not a deficiency — don't tell them to go to bed earlier, that's backwards here."
            : ""
        return """
        Check-in: \(context.window.label), goal type: \(context.kind == .sleep ? "sleep" : "water").
        Details: \(context.detail).
        \(outcome)
        \(streakLine)
        \(overshootLine)
        \(oversleepLine)
        Write the one-line reaction now.
        """
    }

    /// Belt-and-suspenders against the model tacking on a stray trailing
    /// token after a clean sentence (e.g. "...function. 1") despite the
    /// prompt's instruction not to: cut everything after the last terminal
    /// punctuation mark, so what ships always ends cleanly.
    private static func sanitize(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lastPunctuation = result.lastIndex(where: { ".!?".contains($0) }) {
            let cutoff = result.index(after: lastPunctuation)
            if cutoff < result.endIndex {
                result = String(result[..<cutoff])
            }
        }
        return result
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedNudge {
        @Guide(description: "The one or two sentence reaction line, dry and clinical, under 140 characters, no emoji.")
        var text: String
    }
    #endif

    // MARK: - Fallback (no Apple Intelligence available)

    private static func fallback(_ context: NudgeContext) -> NudgeMessage {
        let bank = context.met ? hypeLines(context) : roastLines(context)
        let text = bank.randomElement() ?? "Stay on it."
        return NudgeMessage(text: text)
    }

    private static func roastLines(_ context: NudgeContext) -> [String] {
        if context.isOversleeping {
            return oversleepLines(context)
        }
        switch (context.kind, context.intensity) {
        case (.sleep, .gentle):
            return [
                "\(context.detail). Not fatal. Not great either. Tonight's your chance to fix the chart.",
                "\(context.detail). Your body kept a record. It's not flattering. Go to bed earlier tonight.",
            ]
        case (.sleep, .playful):
            return [
                "\(context.detail). Everybody lies about their sleep. Your data just called you out.",
                "\(context.detail). That's not sleep, that's a nap with commitment issues.",
                "\(context.detail). Diagnosis: mild self-sabotage. Prognosis: fixable, if you go to bed.",
            ]
        case (.sleep, .spicy):
            return [
                "\(context.detail). If exhaustion were a symptom, you'd be a case study.",
                "\(context.detail). You're not tired. You're malpracticing on yourself.",
                "\(context.detail). Patients lie. So, apparently, do you — about going to bed on time.",
            ]
        case (.water, .gentle):
            return [
                "\(context.detail). Mild dehydration won't kill you. It also won't help you. Drink something.",
                "\(context.detail). Low-risk intervention available: water. Consider it.",
            ]
        case (.water, .playful):
            return [
                "\(context.detail). Dehydration isn't a personality trait, it just plays one on you.",
                "\(context.detail). Your kidneys have filed a complaint.",
                "\(context.detail). Everybody lies about drinking enough water. Your urine color doesn't.",
            ]
        case (.water, .spicy):
            return [
                "\(context.detail). This isn't hydration, it's negligence with extra steps.",
                "\(context.detail). You'd fail your own physical right now.",
                "\(context.detail). Somewhere, a kidney is filing paperwork against you.",
            ]
        }
    }

    private static func oversleepLines(_ context: NudgeContext) -> [String] {
        switch context.intensity {
        case .gentle:
            return [
                "\(context.detail). That's more rest than recovery. Worth keeping an eye on.",
                "\(context.detail). Oversleeping has its own side effects. Consider setting an alarm.",
            ]
        case .playful:
            return [
                "\(context.detail). That's not sleep, that's hibernation with extra steps.",
                "\(context.detail). At some point rest becomes a symptom. You've reached that point.",
                "\(context.detail). Impressive. Also concerning. Both can be true.",
            ]
        case .spicy:
            return [
                "\(context.detail). Nobody needs that much sleep. Something's being avoided, and it isn't fatigue.",
                "\(context.detail). That's not recovery, that's a coma with good PR.",
                "\(context.detail). You didn't rest, you disappeared. Get up.",
            ]
        }
    }

    private static func hypeLines(_ context: NudgeContext) -> [String] {
        switch context.kind {
        case .sleep:
            return [
                "\(context.detail). Vitals look good. Try not to ruin it tomorrow.",
                "\(context.detail). Rested and functional — rare, for you.",
                "\(context.detail). Textbook recovery. Don't let it go to your head.",
            ]
        case .water:
            return [
                "\(context.detail). Properly hydrated. Try to act like it's normal.",
                "\(context.detail). Someone's finally treating the patient right.",
                "\(context.detail). Hydration's handled. One fewer thing to diagnose.",
            ]
        }
    }
}
