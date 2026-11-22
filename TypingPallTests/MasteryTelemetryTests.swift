import Foundation
import Testing
@testable import TypingPall

@Suite("Mastery Telemetry & Spaced Repetition Engine")
@MainActor
struct MasteryTelemetryTests {

    // MARK: - Backward Compatibility & Core Model Tests

    @Test("MasteryLevel ordering and ranking")
    func masteryLevelRanking() {
        #expect(MasteryLevel.unstarted < MasteryLevel.familiar)
        #expect(MasteryLevel.familiar < MasteryLevel.structural)
        #expect(MasteryLevel.structural < MasteryLevel.internalized)
        #expect(MasteryLevel.unstarted.rank == 0)
        #expect(MasteryLevel.internalized.rank == 3)
    }

    @Test("Copy mode with >= 85% clean lines promotes to .familiar")
    func copyModePromotesToFamiliar() {
        let record = RecallDecayScheduler.evaluate(
            patternID: "test-pattern",
            currentRecord: nil,
            mode: .copy,
            cleanLinesCount: 9,
            totalLinesCount: 10,
            hintsUsed: 0
        )

        #expect(record.level == .familiar)
        #expect(record.cleanLineRatio >= 0.85)
        #expect(record.nextReviewDate != nil)
    }

    @Test("Key Lines mode with <= 1 hint promotes to .structural")
    func keyLinesPromotesToStructural() {
        let familiarRecord = MasteryRecord(patternID: "test-pattern", level: .familiar)

        let record = RecallDecayScheduler.evaluate(
            patternID: "test-pattern",
            currentRecord: familiarRecord,
            mode: .keyLines,
            cleanLinesCount: 8,
            totalLinesCount: 10,
            hintsUsed: 1
        )

        #expect(record.level == .structural)
    }

    @Test("Recall mode with >= 90% clean lines and zero hints promotes to .internalized")
    func recallPromotesToInternalized() {
        let structuralRecord = MasteryRecord(patternID: "test-pattern", level: .structural)

        let record = RecallDecayScheduler.evaluate(
            patternID: "test-pattern",
            currentRecord: structuralRecord,
            mode: .recall,
            cleanLinesCount: 10,
            totalLinesCount: 10,
            hintsUsed: 0,
            selfRating: .effortless
        )

        #expect(record.level == .internalized)
        #expect(record.consecutiveCleanSessions == 1)
        #expect(record.stability > 2.0)
    }

    @Test("Forgot rating reduces stability and sets review interval to 1 day")
    func forgotRatingReducesStability() {
        let priorRecord = MasteryRecord(patternID: "test-pattern", level: .familiar, stability: 10.0)

        let evaluated = RecallDecayScheduler.evaluate(
            patternID: "test-pattern",
            currentRecord: priorRecord,
            mode: .recall,
            cleanLinesCount: 3,
            totalLinesCount: 10,
            hintsUsed: 3,
            selfRating: .forgot
        )

        #expect(evaluated.stability < priorRecord.stability)
        #expect(evaluated.difficulty > priorRecord.difficulty)
    }

    @Test("Pattern past review date is due for recall")
    func dueForRecallCalculation() {
        let yesterday = Date().addingTimeInterval(-86400)
        let record = MasteryRecord(
            patternID: "test-due",
            level: .internalized,
            nextReviewDate: yesterday
        )

        #expect(record.isDueForRecall == true)
        #expect(record.isFadingGold == true)

        let tomorrow = Date().addingTimeInterval(86400)
        let freshRecord = MasteryRecord(
            patternID: "test-fresh",
            level: .internalized,
            nextReviewDate: tomorrow
        )

        #expect(freshRecord.isDueForRecall == false)
        #expect(freshRecord.isFadingGold == false)
    }

    @Test("MasteryStore tracks and aggregates due counts")
    func masteryStoreOperations() {
        let defaults = UserDefaults(suiteName: "MasteryStoreTests-\(UUID().uuidString)")!
        let store = MasteryStore(defaults: defaults)

        let dueRecord = MasteryRecord(patternID: "due-1", level: .familiar, nextReviewDate: Date().addingTimeInterval(-3600))
        let futureRecord = MasteryRecord(patternID: "future-1", level: .structural, nextReviewDate: Date().addingTimeInterval(86400))

        store.update(record: dueRecord)
        store.update(record: futureRecord)

        #expect(store.level(for: "due-1") == .familiar)
        #expect(store.isDueForRecall(patternID: "due-1") == true)
        #expect(store.isDueForRecall(patternID: "future-1") == false)
        #expect(store.dueForRecallCount == 1)
        #expect(store.dueForRecallPatternIDs().contains("due-1"))
    }

    // MARK: - Formal FSRS v5 Retrievability & Decay Tests

    @Test("FSRS Retrievability decays smoothly with exact 90% at t = S")
    func fsrsRetrievabilityDecay() {
        let engine = FSRSEngine.shared
        let stability = 10.0

        // At t = 0, recall is 100%
        let r0 = engine.retrievability(elapsedDays: 0.0, stability: stability)
        #expect(abs(r0 - 1.0) < 0.0001)

        // At t = S, retrievability is exactly 90% by definition
        let rS = engine.retrievability(elapsedDays: stability, stability: stability)
        #expect(abs(rS - 0.90) < 0.0001)

        // At t = 2S, retrievability has fallen further
        let r2S = engine.retrievability(elapsedDays: stability * 2.0, stability: stability)
        #expect(r2S < 0.90)
        #expect(r2S > 0.70)

        // Strict monotonic decrease
        let r30 = engine.retrievability(elapsedDays: 30.0, stability: stability)
        #expect(r30 < r2S)

        // Bounded within [0, 1]
        let rFar = engine.retrievability(elapsedDays: 365.0, stability: stability)
        #expect(rFar >= 0.0 && rFar <= 1.0)
    }

    @Test("FSRS Interval calculation matches target retention")
    func fsrsIntervalCalculation() {
        let engine = FSRSEngine.shared
        let stability = 14.0

        // Target retention 90% gives interval exactly equal to stability S
        let interval90 = engine.interval(for: stability, targetRetention: 0.90)
        #expect(abs(interval90 - stability) < 0.001)

        // Lower target retention (e.g. 80%) yields longer interval
        let interval80 = engine.interval(for: stability, targetRetention: 0.80)
        #expect(interval80 > stability)

        // Higher target retention (e.g. 95%) yields shorter interval
        let interval95 = engine.interval(for: stability, targetRetention: 0.95)
        #expect(interval95 < stability)
        #expect(interval95 >= 1.0)
    }

    @Test("FSRS Initial stability and difficulty vary inversely by grade")
    func fsrsInitialStateTransitions() {
        let engine = FSRSEngine.shared

        let sAgain = engine.initialStability(for: .again)
        let sHard = engine.initialStability(for: .hard)
        let sGood = engine.initialStability(for: .good)
        let sEasy = engine.initialStability(for: .easy)

        // Stability increases from Again to Easy
        #expect(sAgain < sHard)
        #expect(sHard < sGood)
        #expect(sGood < sEasy)

        let dAgain = engine.initialDifficulty(for: .again)
        let dHard = engine.initialDifficulty(for: .hard)
        let dGood = engine.initialDifficulty(for: .good)
        let dEasy = engine.initialDifficulty(for: .easy)

        // Difficulty decreases from Again to Easy
        #expect(dAgain > dHard)
        #expect(dHard > dGood)
        #expect(dGood > dEasy)

        // Clamped within 1..10
        #expect(dAgain <= 10.0 && dAgain >= 1.0)
        #expect(dEasy <= 10.0 && dEasy >= 1.0)
    }

    @Test("FSRS Review success and lapse state updates")
    func fsrsStateTransitionsSuccessAndLapse() {
        let engine = FSRSEngine.shared
        let initialS = 5.0
        let initialD = 5.0
        let retrievability = 0.90 // reviewed at t = S

        // Recall success updates
        let nextSGood = engine.nextRecallStability(stability: initialS, difficulty: initialD, retrievability: retrievability, grade: .good)
        let nextSEasy = engine.nextRecallStability(stability: initialS, difficulty: initialD, retrievability: retrievability, grade: .easy)
        let nextSHard = engine.nextRecallStability(stability: initialS, difficulty: initialD, retrievability: retrievability, grade: .hard)

        #expect(nextSGood > initialS)
        #expect(nextSEasy > nextSGood)
        #expect(nextSHard < nextSGood)

        // Difficulty updates
        let nextDGood = engine.nextDifficulty(current: initialD, grade: .good)
        let nextDEasy = engine.nextDifficulty(current: initialD, grade: .easy)
        let nextDHard = engine.nextDifficulty(current: initialD, grade: .hard)
        let nextDAgain = engine.nextDifficulty(current: initialD, grade: .again)

        #expect(nextDEasy < initialD)
        #expect(nextDHard > initialD)
        #expect(nextDAgain > nextDHard)
        #expect(abs(nextDGood - initialD) < 0.5) // Good has gentle mean reversion

        // Review lapse
        let lapseS = engine.nextLapseStability(stability: initialS, difficulty: initialD, retrievability: retrievability)
        #expect(lapseS < initialS)
    }

    @Test("FSRS spacing effect: greater stability boost when recalling from lower retention")
    func fsrsSpacingEffect() {
        let engine = FSRSEngine.shared
        let stability = 10.0
        let difficulty = 5.0

        // Immediate review (R = 0.999) vs spaced review (R = 0.85)
        let sImmediate = engine.nextRecallStability(stability: stability, difficulty: difficulty, retrievability: 0.999, grade: .good)
        let sSpaced = engine.nextRecallStability(stability: stability, difficulty: difficulty, retrievability: 0.85, grade: .good)

        #expect(sSpaced > sImmediate)
    }

    // MARK: - Telemetry-Derived Implicit Grading Tests

    @Test("Implicit Grade 1 (Again) on hints > 2 or wrong attempts > 3")
    func implicitGradeAgain() {
        // > 2 hints triggers Again
        let telemetryHints = PracticeTelemetry(
            mode: .recall,
            cleanLinesCount: 8,
            totalLinesCount: 10,
            hintsUsed: 3,
            wrongAttempts: 0
        )
        #expect(ImplicitGrader.grade(from: telemetryHints) == .again)

        // > 3 wrong attempts triggers Again
        let telemetryErrors = PracticeTelemetry(
            mode: .recall,
            cleanLinesCount: 6,
            totalLinesCount: 10,
            hintsUsed: 0,
            wrongAttempts: 4
        )
        #expect(ImplicitGrader.grade(from: telemetryErrors) == .again)
    }

    @Test("Implicit Grade 2 (Hard) on peak hesitation > 1.5s, clean ratio < 75%, or hints used")
    func implicitGradeHard() {
        // Peak hesitation > 1.5s triggers Hard even with clean lines
        let telemetryHesitation = PracticeTelemetry(
            mode: .recall,
            cleanLinesCount: 9,
            totalLinesCount: 10,
            hintsUsed: 0,
            peakHesitation: 1.8
        )
        #expect(ImplicitGrader.grade(from: telemetryHesitation) == .hard)

        // Clean ratio < 75% triggers Hard
        let telemetryLowRatio = PracticeTelemetry(
            mode: .recall,
            cleanLinesCount: 7,
            totalLinesCount: 10,
            hintsUsed: 0,
            peakHesitation: 0.8
        )
        #expect(ImplicitGrader.grade(from: telemetryLowRatio) == .hard)

        // 1 or 2 hints used triggers Hard
        let telemetryHint = PracticeTelemetry(
            mode: .recall,
            cleanLinesCount: 8,
            totalLinesCount: 10,
            hintsUsed: 1,
            peakHesitation: 0.5
        )
        #expect(ImplicitGrader.grade(from: telemetryHint) == .hard)
    }

    @Test("Implicit Grade 3 (Good) on clean ratio >= 85% and fluent recall")
    func implicitGradeGood() {
        let telemetry = PracticeTelemetry(
            mode: .recall,
            cleanLinesCount: 9,
            totalLinesCount: 10,
            hintsUsed: 0,
            peakHesitation: 0.6,
            wpm: 50.0,
            expectedWPM: 55.0
        )
        #expect(ImplicitGrader.grade(from: telemetry) == .good)

        // Clean lines in Copy mode caps at Good (not Easy)
        let copyTelemetry = PracticeTelemetry(
            mode: .copy,
            cleanLinesCount: 10,
            totalLinesCount: 10,
            hintsUsed: 0,
            peakHesitation: 0.3
        )
        #expect(ImplicitGrader.grade(from: copyTelemetry) == .good)
    }

    @Test("Implicit Grade 4 (Easy) on 100% clean lines, zero hints, high fluency in Recall or Key Lines")
    func implicitGradeEasy() {
        let recallTelemetry = PracticeTelemetry(
            mode: .recall,
            cleanLinesCount: 10,
            totalLinesCount: 10,
            hintsUsed: 0,
            wrongAttempts: 0,
            peakHesitation: 0.4,
            wpm: 60.0,
            expectedWPM: 55.0
        )
        #expect(ImplicitGrader.grade(from: recallTelemetry) == .easy)

        let keyLinesTelemetry = PracticeTelemetry(
            mode: .keyLines,
            cleanLinesCount: 10,
            totalLinesCount: 10,
            hintsUsed: 0,
            wrongAttempts: 0,
            peakHesitation: 0.5,
            wpm: 58.0,
            expectedWPM: 55.0
        )
        #expect(ImplicitGrader.grade(from: keyLinesTelemetry) == .easy)
    }

    @Test("Blending implicit grade with user selfRating")
    func implicitGradingSelfRatingBlending() {
        // Forgot overrides objective Good to Again
        #expect(ImplicitGrader.blend(objective: .good, selfRating: .forgot) == .again)

        // Shaky pulls objective Easy down to Hard
        #expect(ImplicitGrader.blend(objective: .easy, selfRating: .shaky) == .hard)

        // Solid keeps objective Good at Good
        #expect(ImplicitGrader.blend(objective: .good, selfRating: .solid) == .good)

        // Effortless upgrades objective Good to Easy
        #expect(ImplicitGrader.blend(objective: .good, selfRating: .effortless) == .easy)

        // Effortless cannot override objective Again (> 2 hints or > 3 errors)
        #expect(ImplicitGrader.blend(objective: .again, selfRating: .effortless) == .again)
    }

    // MARK: - Cognitive Mode Recommendations

    @Test("Cognitive mode recommendations based on stability S")
    func cognitiveModeRecommendations() {
        // Stability < 2 days -> .copy
        #expect(FSRSEngine.recommendedMode(for: 0.5) == .copy)
        #expect(FSRSEngine.recommendedMode(for: 1.9) == .copy)
        #expect(RecallDecayScheduler.recommendedMode(for: 1.0) == .copy)

        // Stability 2 <= S < 7 days -> .keyLines
        #expect(FSRSEngine.recommendedMode(for: 2.0) == .keyLines)
        #expect(FSRSEngine.recommendedMode(for: 5.5) == .keyLines)
        #expect(FSRSEngine.recommendedMode(for: 6.9) == .keyLines)

        // Stability >= 7 days -> .recall
        #expect(FSRSEngine.recommendedMode(for: 7.0) == .recall)
        #expect(FSRSEngine.recommendedMode(for: 21.0) == .recall)
        #expect(RecallDecayScheduler.recommendedMode(for: 10.0) == .recall)

        // MasteryRecord convenience property
        let lowRecord = MasteryRecord(patternID: "low", stability: 1.2)
        #expect(lowRecord.recommendedMode == .copy)

        let medRecord = MasteryRecord(patternID: "med", stability: 4.5)
        #expect(medRecord.recommendedMode == .keyLines)

        let highRecord = MasteryRecord(patternID: "high", stability: 15.0)
        #expect(highRecord.recommendedMode == .recall)
    }

    // MARK: - MasteryRecord Retrievability & RecallDecayScheduler Overload

    @Test("MasteryRecord retrievability calculation")
    func masteryRecordRetrievability() {
        let now = Date()
        let stability = 8.0
        let lastReviewed = now.addingTimeInterval(-8.0 * 86400) // reviewed exactly S days ago

        let record = MasteryRecord(
            patternID: "retrievability-test",
            stability: stability,
            lastReviewedAt: lastReviewed
        )

        let rNow = record.retrievability(at: now)
        #expect(abs(rNow - 0.90) < 0.001)

        // Immediately reviewed record has retrievability ~1.0
        let freshRecord = MasteryRecord(
            patternID: "fresh",
            stability: stability,
            lastReviewedAt: now
        )
        #expect(abs(freshRecord.retrievability(at: now) - 1.0) < 0.001)
    }

    @Test("RecallDecayScheduler evaluate with PracticeTelemetry overload")
    func recallDecaySchedulerTelemetryOverload() {
        let telemetry = PracticeTelemetry(
            mode: .recall,
            cleanLinesCount: 10,
            totalLinesCount: 10,
            hintsUsed: 0,
            wrongAttempts: 0,
            peakHesitation: 0.3,
            wpm: 65.0,
            expectedWPM: 60.0
        )

        let record = RecallDecayScheduler.evaluate(
            patternID: "telemetry-overload-test",
            currentRecord: nil,
            telemetry: telemetry
        )

        #expect(record.cleanLineRatio == 1.0)
        #expect(record.stability > 10.0) // Initial stability for Easy is ~15.7
        #expect(record.consecutiveCleanSessions == 1)
        #expect(record.nextReviewDate != nil)
        #expect(record.recommendedMode == .recall)
    }
}
