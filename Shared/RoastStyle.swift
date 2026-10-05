import Foundation

enum RoastTarget: String, Sendable {
    case missingData
    case allGood
    case overallBad
    case overallUgly
    case sleepUnder
    case sleepOver
    case sleepMet
    case waterIncomplete
    case waterMet
    case foodBad
    case foodUgly
    case foodGood
    case sleepConsistency
    case waterConsistency
    case foodQuality
    case trendImproving
    case trendSteady
    case trendSlipping
    case baselineThin

    fileprivate var brief: String {
        switch self {
        case .missingData: "The user left required tracking data incomplete."
        case .allGood: "The user performed well; roast complacency, not a nonexistent failure."
        case .overallBad: "The verified overall result is Bad; roast only the day's execution without naming a metric."
        case .overallUgly: "The verified overall result is Ugly; roast only the day's execution without naming a metric."
        case .sleepUnder: "The verified sleep duration was below the configured range."
        case .sleepOver: "The verified sleep duration was above the configured range."
        case .sleepMet: "The verified sleep duration was within range; roast only the rarity of competence."
        case .waterIncomplete: "The verified full-day water goal was incomplete."
        case .waterMet: "The verified full-day water goal was completed; roast only the rarity of competence."
        case .foodBad: "The deterministic food status is Bad."
        case .foodUgly: "The deterministic food status is Ugly."
        case .foodGood: "The deterministic food status is Good; roast only complacency."
        case .sleepConsistency: "The verified longitudinal priority is sleep consistency."
        case .waterConsistency: "The verified longitudinal priority is water completion."
        case .foodQuality: "The verified longitudinal priority is food quality."
        case .trendImproving: "The verified longitudinal direction is improving; roast complacency."
        case .trendSteady: "The verified longitudinal direction is steady; roast stagnation."
        case .trendSlipping: "The verified longitudinal direction is slipping."
        case .baselineThin: "There is not enough verified history for a trend."
        }
    }

    fileprivate var allowedTopic: RoastTopic? {
        switch self {
        case .sleepUnder, .sleepOver, .sleepMet, .sleepConsistency: .sleep
        case .waterIncomplete, .waterMet, .waterConsistency: .water
        case .foodBad, .foodUgly, .foodGood, .foodQuality: .food
        case .missingData, .allGood, .overallBad, .overallUgly,
             .trendImproving, .trendSteady, .trendSlipping, .baselineThin: nil
        }
    }
}

enum RoastStyleContract {
    static func modelInstructions(target: RoastTarget, intensity: RoastIntensity) -> String {
        """
        Write one original Dr Jay roast about exactly this verified target:
        \(target.brief)

        \(styleDirective(intensity))

        Do not reinterpret the target, invent another failure, mention an unrelated metric, give advice, moralize,
        diagnose, or explain the joke. Target the user's choices only—never body, weight, identity, intelligence,
        health conditions, calorie intake, or worth. No profanity, emoji, hashtags, quotation marks, eating-disorder language, or
        references to real or fictional people. Return only the roast sentence.
        """
    }

    static func styleDirective(_ intensity: RoastIntensity) -> String {
        switch intensity {
        case .gentle:
            "GENTLE contract: indirect clinical irony, no you/your accusation, one understated sentence of 6–20 words. Let implication do the work."
        case .playful:
            "PLAYFUL contract: address you/your directly, use one concrete absurd analogy, and land a clear setup-to-punch turn in 8–26 words."
        case .spicy:
            "SPICY contract: address you/your directly, make a blunt accusation, escalate it with a ruthless absurd image, and end on the hardest word in 7–20 words. No hedging, encouragement, advice, or soft landing."
        }
    }

    static func validated(
        _ candidate: String?,
        target: RoastTarget,
        intensity: RoastIntensity
    ) -> String? {
        guard let candidate else { return nil }
        let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.count <= 220,
              !value.contains("\n"),
              !value.contains(where: \.isNumber)
        else { return nil }

        let words = value.lowercased().split { !$0.isLetter }.map(String.init)
        let wordSet = Set(words)
        guard words.count >= 5 else { return nil }

        let secondPerson = !wordSet.isDisjoint(with: ["you", "your", "youre", "youve"])
        switch intensity {
        case .gentle:
            guard !secondPerson, words.count <= 20 else { return nil }
        case .playful:
            guard secondPerson, words.count <= 26 else { return nil }
        case .spicy:
            guard secondPerson, words.count <= 20 else { return nil }
            let hedges: Set<String> = ["perhaps", "maybe", "might", "could", "consider", "apparently"]
            guard hedges.isDisjoint(with: wordSet) else { return nil }
        }

        let preaching: Set<String> = [
            "should", "need", "needs", "must", "try", "remember", "focus", "improve", "finish", "protect",
            "maintain", "start", "stop",
        ]
        let personalAttacks: Set<String> = [
            "fat", "lazy", "stupid", "idiot", "pathetic", "worthless", "body", "weight", "ugly",
            "calorie", "calories",
        ]
        guard preaching.isDisjoint(with: wordSet), personalAttacks.isDisjoint(with: wordSet) else { return nil }

        for topic in RoastTopic.allCases where topic != target.allowedTopic {
            guard topic.words.isDisjoint(with: wordSet) else { return nil }
        }
        return String(value.prefix(220))
    }

    static func fallback(
        target: RoastTarget,
        intensity: RoastIntensity,
        excluding previous: String? = nil
    ) -> String {
        let candidates = fallbackCandidates(target: target, intensity: intensity)
        return candidates.first { candidate in
            !(previous?.localizedCaseInsensitiveContains(candidate) ?? false)
        } ?? candidates[0]
    }

    private static func fallbackCandidates(
        target: RoastTarget,
        intensity: RoastIntensity
    ) -> [String] {
        switch (target, intensity) {
        case (.missingData, .gentle): ["The paperwork appears to have developed a fear of evidence.", "The case notes remain admirably free of useful information."]
        case (.missingData, .playful): ["You submitted a blank chart and expected the confidence of a diagnosis.", "You brought paperwork to rounds and forgot the part containing evidence."]
        case (.missingData, .spicy): ["You submitted absence as evidence and expected applause for documentation.", "You abandoned the chart halfway through and still demanded a verdict."]

        case (.allGood, .gentle): ["Competence has made a rare but documented appearance.", "The chart appears pleasantly surprised by basic consistency."]
        case (.allGood, .playful): ["You followed basic instructions and now the chart wants a commemorative plaque.", "You behaved sensibly for once and the evidence is treating it like a miracle."]
        case (.allGood, .spicy): ["You cleared medicine’s floor-level bar without tripping—historic.", "You performed basic maintenance once and immediately applied for sainthood."]

        case (.overallBad, .gentle): ["The day appears to have mistaken adequacy for achievement.", "The overall performance remains politely below convincing."]
        case (.overallBad, .playful): ["You assembled a whole day and somehow left quality control in the waiting room.", "You delivered a day so average the chart requested a second opinion."]
        case (.overallBad, .spicy): ["You produced a full day of effort and still missed competence.", "You turned twenty-four hours into an administrative warning."
        ]

        case (.overallUgly, .gentle): ["The day’s execution appears to require discreet internal review.", "The overall result has made a compelling case for revision."]
        case (.overallUgly, .playful): ["You ran the entire day like the instruction manual was decorative.", "You gave the day every opportunity and it filed for witness protection."]
        case (.overallUgly, .spicy): ["You turned an entire day into evidence of operational collapse.", "You managed twenty-four hours like competence was contraband."]

        case (.sleepUnder, .gentle): ["The night appears to have been managed with optimistic accounting.", "Rest was apparently considered an optional administrative detail."]
        case (.sleepUnder, .playful): ["You treated bedtime like a deadline and missed it with professional confidence.", "You gave recovery a cameo and expected it to carry the entire production."]
        case (.sleepUnder, .spicy): ["You sabotaged tomorrow before today had the decency to end.", "You robbed tomorrow’s brain and left exhaustion holding the receipt."]

        case (.sleepOver, .gentle): ["Recovery appears to have acquired permanent residency.", "Rest quietly crossed the border into disappearance."]
        case (.sleepOver, .playful): ["You treated waking up like an optional feature in the operating system.", "You entered the mattress and returned after the search party lost interest."]
        case (.sleepOver, .spicy): ["You vanished into a mattress and called the disappearance healthcare.", "You surrendered an entire day to a pillow and named it recovery."]

        case (.sleepMet, .gentle): ["The night was handled with suspicious competence.", "Adequate recovery has made an unexpectedly professional appearance."]
        case (.sleepMet, .playful): ["You followed a bedtime and now the chart wants a commemorative plaque.", "You slept responsibly once and the evidence is considering a press release."]
        case (.sleepMet, .spicy): ["You cleared bedtime’s floor-level bar without engineering your usual disaster.", "You managed basic recovery without sabotaging it—an administrative miracle."]

        case (.waterIncomplete, .gentle): ["Hydration appears to have been treated as an administrative suggestion.", "The bottle spent another day serving mainly as office decor."]
        case (.waterIncomplete, .playful): ["You turned drinking water into an optional side quest with no completion badge.", "You made a nearby bottle feel like inaccessible medical technology."]
        case (.waterIncomplete, .spicy): ["You made basic hydration look intellectually demanding.", "You lost an argument to a bottle that cannot speak."]

        case (.waterMet, .gentle): ["Hydration was completed with almost suspicious professionalism.", "The bottle finally appears to have received its job description."]
        case (.waterMet, .playful): ["You finished the bottle quota and now your kidneys want a parade.", "You drank enough water and briefly resembled a functioning adult."]
        case (.waterMet, .spicy): ["You completed basic hydration without turning it into a personal crisis—historic.", "You defeated a bottle today; civilization may yet recover."]

        case (.foodBad, .gentle): ["The menu showed enthusiasm where judgment would have helped.", "Nutritional intent appears to have left before the order arrived."]
        case (.foodBad, .playful): ["You assembled that plate like vegetables had secured legal protection.", "You fed the craving and left nutrition waiting outside without an appointment."]
        case (.foodBad, .spicy): ["You ate like nutrition had personally offended you.", "You turned a meal into evidence and handed the prosecution everything."]

        case (.foodUgly, .gentle): ["The menu has moved beyond questionable into professionally concerning.", "Nutritional judgment appears to have taken the day off without notice."]
        case (.foodUgly, .playful): ["You built that menu like the pantry was settling a personal vendetta.", "You made a meal so chaotic the plate deserves witness protection."]
        case (.foodUgly, .spicy): ["You committed dietary malpractice and plated the evidence.", "You ate like consequences were a subscription you had cancelled."]

        case (.foodGood, .gentle): ["The menu displays an unfamiliar but welcome degree of judgment.", "Nutritional competence has entered the building quietly."]
        case (.foodGood, .playful): ["You assembled a sensible plate and briefly confused the entire case history.", "You fed yourself responsibly and now the pantry expects a personality change."]
        case (.foodGood, .spicy): ["You made one competent menu and immediately endangered your reputation for chaos.", "You ate sensibly without staging a rebellion—deeply inconvenient for your excuses."]

        case (.sleepConsistency, .gentle): ["The sleep pattern remains more improvisation than routine.", "Recovery appears to be operating without a published schedule."]
        case (.sleepConsistency, .playful): ["You schedule recovery like a surprise meeting nobody agreed to attend.", "You made bedtime less predictable than a hospital vending machine."]
        case (.sleepConsistency, .spicy): ["You run recovery like an unlicensed night shift.", "You turned bedtime into chaos and promoted exhaustion to management."]

        case (.waterConsistency, .gentle): ["Hydration remains an occasional visitor rather than established policy.", "The bottle appears to work on a highly flexible contract."]
        case (.waterConsistency, .playful): ["You manage hydration like an intern who keeps losing the checklist.", "You made routine drinking feel like a quarterly infrastructure project."]
        case (.waterConsistency, .spicy): ["You turned basic hydration into recurring operational failure.", "You keep losing the same argument to an inanimate bottle."]

        case (.foodQuality, .gentle): ["The menu pattern suggests judgment is still under observation.", "Nutritional consistency remains more theory than practice."]
        case (.foodQuality, .playful): ["You curate meals like the pantry is running an unsupervised experiment.", "You made nutritional consistency disappear faster than the snacks."]
        case (.foodQuality, .spicy): ["You turned repeated meals into a case study in avoidable sabotage.", "You keep plating bad judgment and calling repetition a routine."]

        case (.trendImproving, .gentle): ["Progress has appeared; permanence has not yet returned the call.", "The evidence is improving without becoming smug about it."]
        case (.trendImproving, .playful): ["You improved enough to make your old excuses look medically obsolete.", "You found consistency and now your previous chaos wants severance pay."]
        case (.trendImproving, .spicy): ["You finally improved and exposed every previous excuse as decorative nonsense.", "You proved competence was available and made your old failures look deliberate."]

        case (.trendSteady, .gentle): ["Stability has arrived, though ambition appears delayed.", "The pattern is steady enough to avoid excitement."]
        case (.trendSteady, .playful): ["You achieved consistency and somehow chose the least interesting version of it.", "You held the line so firmly progress filed a change request."]
        case (.trendSteady, .spicy): ["You mastered standing still and mistook it for progress.", "You built a plateau and started charging it rent."]

        case (.trendSlipping, .gentle): ["The pattern appears to be misplacing its earlier competence.", "The evidence has begun moving in an unhelpful direction."]
        case (.trendSlipping, .playful): ["You found momentum and confidently pointed it toward the basement.", "You turned a manageable pattern into a sequel nobody requested."]
        case (.trendSlipping, .spicy): ["You converted progress into evidence against yourself.", "You watched the pattern decline and apparently volunteered as supervisor."]

        case (.baselineThin, .gentle): ["The evidence remains too shy to become a pattern.", "The case notes need substance before they acquire confidence."]
        case (.baselineThin, .playful): ["You brought a handful of dots and demanded the authority of a trend line.", "You submitted a coincidence and asked the chart to call it research."]
        case (.baselineThin, .spicy): ["You collected an anecdote and demanded statistical respect.", "You handed the chart crumbs and expected forensic certainty."]
        }
    }
}

private enum RoastTopic: CaseIterable {
    case sleep
    case water
    case food
    case steps

    var words: Set<String> {
        switch self {
        case .sleep: ["sleep", "slept", "bedtime", "rest", "recovery", "night", "mattress", "pillow", "exhaustion"]
        case .water: ["water", "hydration", "hydrate", "bottle", "bottles", "kidney", "kidneys", "drink", "drinking"]
        case .food: ["food", "meal", "meals", "menu", "plate", "pantry", "nutrition", "nutritional", "dietary", "eat", "ate", "snack", "snacks"]
        case .steps: ["step", "steps", "walking", "walk", "movement", "exercise", "workout", "gym", "run", "running"]
        }
    }
}
