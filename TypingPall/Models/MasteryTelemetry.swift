import SwiftUI
import Foundation

// MARK: - 3-Tier Mastery Badges

public enum MasteryLevel: String, Codable, Sendable, Comparable {
    case unstarted
    case familiar      // Stage 1: Bronze (Copy mode >= 85% clean lines)
    case structural    // Stage 2: Silver (Key Lines mode <= 1 hint)
    case internalized  // Stage 3: Gold (Recall mode >= 90% clean lines)

    public var rank: Int {
        switch self {
        case .unstarted: return 0
        case .familiar: return 1
        case .structural: return 2
        case .internalized: return 3
        }
    }

    public static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    public var color: Color {
        switch self {
        case .unstarted: return Color.secondary.opacity(0.3)
        case .familiar: return Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
        case .structural: return Color(red: 0.75, green: 0.78, blue: 0.82) // Silver
        case .internalized: return Color(red: 0.96, green: 0.77, blue: 0.20) // Gold
        }
    }

    public var title: String {
        switch self {
        case .unstarted: return "Unstarted"
        case .familiar: return "Familiar"
        case .structural: return "Structural"
        case .internalized: return "Internalized"
        }
    }
}

// MARK: - FSRS v5 Parameters & Memory State

public struct FSRSParameters: Codable, Sendable, Equatable {
    /// 19 default weights for FSRS v5
    public var w: [Double]
    /// Forgetting curve decay parameter (default 0.5)
    public var decay: Double
    /// Target retention rate (default 0.90)
    public var targetRetention: Double

    public static let `default` = FSRSParameters(
        w: [
            0.40255,   // w[0]: S0(Again)
            1.18385,   // w[1]: S0(Hard)
            3.173,     // w[2]: S0(Good)
            15.69105,  // w[3]: S0(Easy)
            7.1949,    // w[4]: D0 base
            0.5345,    // w[5]: D0 grade scale
            1.4604,    // w[6]: D update delta scale
            0.0046,    // w[7]: D update mean reversion
            1.54575,   // w[8]: S recall base
            0.1192,    // w[9]: S recall stability power
            1.01925,   // w[10]: S recall retrievability scale
            1.9395,    // w[11]: S lapse base
            0.11,      // w[12]: S lapse difficulty power
            0.29605,   // w[13]: S lapse stability power
            0.22695,   // w[14]: S lapse retrievability scale
            0.56995,   // w[15]: Hard penalty factor
            2.85535,   // w[16]: Easy bonus factor
            0.52385,   // w[17]: Short-term stability factor
            0.3152     // w[18]: Short-term lapse factor
        ],
        decay: 0.5,
        targetRetention: 0.90
    )

    public init(w: [Double] = FSRSParameters.default.w, decay: Double = 0.5, targetRetention: Double = 0.90) {
        self.w = w
        self.decay = decay
        self.targetRetention = targetRetention
    }

    /// Retention factor derived from decay: (0.9^(-1/decay) - 1.0)
    public var factor: Double {
        pow(0.9, -1.0 / decay) - 1.0
    }
}

public struct FSRSMemoryState: Codable, Sendable, Equatable {
    public var stability: Double     // S in days (S > 0)
    public var difficulty: Double    // D in [1.0, 10.0]
    public var lastReviewedAt: Date?

    public init(stability: Double = 1.0, difficulty: Double = 5.0, lastReviewedAt: Date? = nil) {
        self.stability = max(0.1, stability)
        self.difficulty = min(10.0, max(1.0, difficulty))
        self.lastReviewedAt = lastReviewedAt
    }
}

// MARK: - Formal FSRS v5 Spaced Repetition Engine

public final class FSRSEngine: Sendable {
    public static let shared = FSRSEngine()

    public let parameters: FSRSParameters

    public init(parameters: FSRSParameters = .default) {
        self.parameters = parameters
    }

    /// Calculate retrievability R(t, S) = (1 + factor * (t / S))^(-decay)
    public func retrievability(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0.0 }
        let t = max(0.0, elapsedDays)
        let s = max(0.01, stability)
        let r = pow(1.0 + parameters.factor * (t / s), -parameters.decay)
        return min(1.0, max(0.0, r))
    }

    public static func retrievability(elapsedDays: Double, stability: Double) -> Double {
        shared.retrievability(elapsedDays: elapsedDays, stability: stability)
    }

    /// Calculate review interval I(r, S) = (S / factor) * (r^(-1/decay) - 1)
    public func interval(for stability: Double, targetRetention: Double? = nil) -> Double {
        let r = targetRetention ?? parameters.targetRetention
        guard stability > 0, r > 0, r < 1.0 else { return max(1.0, stability) }
        let rawInterval = (stability / parameters.factor) * (pow(r, -1.0 / parameters.decay) - 1.0)
        return max(1.0, rawInterval)
    }

    public static func interval(for stability: Double, targetRetention: Double? = nil) -> Double {
        shared.interval(for: stability, targetRetention: targetRetention)
    }

    /// FSRS initial difficulty D0(G) = w[4] - e^(w[5] * (G - 1)) + 1
    public func initialDifficulty(for grade: ReviewGrade) -> Double {
        let g = Double(grade.rawValue)
        let d = parameters.w[4] - exp(parameters.w[5] * (g - 1.0)) + 1.0
        return min(10.0, max(1.0, d))
    }

    /// FSRS initial stability S0(G) = w[G - 1]
    public func initialStability(for grade: ReviewGrade) -> Double {
        let idx = min(max(0, grade.rawValue - 1), 3)
        return max(0.1, parameters.w[idx])
    }

    /// Next difficulty after review:
    /// Delta D = -w[6] * (G - 3)
    /// D_raw = D + Delta D
    /// D_next = w[7] * D0(3) + (1 - w[7]) * D_raw
    public func nextDifficulty(current: Double, grade: ReviewGrade) -> Double {
        let g = Double(grade.rawValue)
        let deltaD = -parameters.w[6] * (g - 3.0)
        let dRaw = current + deltaD
        let d0Good = initialDifficulty(for: .good)
        let dNext = parameters.w[7] * d0Good + (1.0 - parameters.w[7]) * dRaw
        return min(10.0, max(1.0, dNext))
    }

    /// Next stability on recall success (Grade 2, 3, or 4):
    /// S_recall = S * (1 + e^(w[8]) * (11 - D) * S^(-w[9]) * (e^((1 - R) * w[10]) - 1) * h(G))
    public func nextRecallStability(stability: Double, difficulty: Double, retrievability: Double, grade: ReviewGrade) -> Double {
        let s = max(0.1, stability)
        let d = min(10.0, max(1.0, difficulty))
        let r = min(1.0, max(0.0, retrievability))

        let hardPenalty = parameters.w[15]
        let easyBonus = parameters.w[16]

        let h: Double
        switch grade {
        case .again: h = 0.0
        case .hard: h = hardPenalty
        case .good: h = 1.0
        case .easy: h = easyBonus
        }

        let baseGrowth = exp(parameters.w[8]) * (11.0 - d) * pow(s, -parameters.w[9]) * (exp((1.0 - r) * parameters.w[10]) - 1.0) * h

        // Immediate / short-interval review protection:
        // When elapsed time is near 0 (R -> 1.0), baseGrowth -> 0. FSRS parameter w[17] provides baseline short-term growth.
        let shortTermGrowth = parameters.w[17] * h * ((11.0 - d) / 10.0)
        let growth = max(baseGrowth, shortTermGrowth)

        return max(s, s * (1.0 + growth))
    }

    /// Next stability on review lapse (Grade 1):
    /// S_lapse = w[11] * D^(-w[12]) * ((S + 1)^w[13] - 1) * e^((1 - R) * w[14])
    public func nextLapseStability(stability: Double, difficulty: Double, retrievability: Double) -> Double {
        let s = max(0.1, stability)
        let d = min(10.0, max(1.0, difficulty))
        let r = min(1.0, max(0.0, retrievability))

        let lapseS = parameters.w[11] * pow(d, -parameters.w[12]) * (pow(s + 1.0, parameters.w[13]) - 1.0) * exp((1.0 - r) * parameters.w[14])
        return min(s, max(0.1, lapseS))
    }

    /// Step memory state forward given grade and current date
    public func step(state: FSRSMemoryState?, grade: ReviewGrade, now: Date = Date()) -> (state: FSRSMemoryState, interval: Double) {
        guard let current = state, let lastReviewedAt = current.lastReviewedAt else {
            let s0 = initialStability(for: grade)
            let d0 = initialDifficulty(for: grade)
            let newState = FSRSMemoryState(stability: s0, difficulty: d0, lastReviewedAt: now)
            let iv = grade == .again ? 1.0 : interval(for: s0)
            return (newState, iv)
        }

        let elapsedDays = max(0.0, now.timeIntervalSince(lastReviewedAt) / 86400.0)
        let r = retrievability(elapsedDays: elapsedDays, stability: current.stability)
        let nextD = nextDifficulty(current: current.difficulty, grade: grade)

        let nextS: Double
        let nextInterval: Double

        if grade == .again {
            nextS = nextLapseStability(stability: current.stability, difficulty: current.difficulty, retrievability: r)
            nextInterval = 1.0
        } else {
            nextS = nextRecallStability(stability: current.stability, difficulty: current.difficulty, retrievability: r, grade: grade)
            nextInterval = interval(for: nextS)
        }

        let newState = FSRSMemoryState(stability: nextS, difficulty: nextD, lastReviewedAt: now)
        return (newState, nextInterval)
    }

    /// Cognitive mode recommendation based on stability S:
    /// - Low stability (< 2 days): .copy
    /// - Medium stability (2 <= S < 7 days): .keyLines
    /// - High stability (>= 7 days): .recall
    public static func recommendedMode(for stability: Double) -> PracticeMode {
        if stability < 2.0 {
            return .copy
        } else if stability < 7.0 {
            return .keyLines
        } else {
            return .recall
        }
    }
}

// MARK: - Telemetry-Derived Implicit Grading

public struct PracticeTelemetry: Sendable, Equatable {
    public var mode: PracticeMode
    public var cleanLinesCount: Int
    public var totalLinesCount: Int
    public var hintsUsed: Int
    public var wrongAttempts: Int
    public var peakHesitation: TimeInterval
    public var hesitationCount: Int
    public var wpm: Double
    public var expectedWPM: Double?
    public var selfRating: SelfRating?

    public init(
        mode: PracticeMode = .recall,
        cleanLinesCount: Int = 0,
        totalLinesCount: Int = 1,
        hintsUsed: Int = 0,
        wrongAttempts: Int = 0,
        peakHesitation: TimeInterval = 0.0,
        hesitationCount: Int = 0,
        wpm: Double = 0.0,
        expectedWPM: Double? = nil,
        selfRating: SelfRating? = nil
    ) {
        self.mode = mode
        self.cleanLinesCount = cleanLinesCount
        self.totalLinesCount = max(1, totalLinesCount)
        self.hintsUsed = hintsUsed
        self.wrongAttempts = wrongAttempts
        self.peakHesitation = peakHesitation
        self.hesitationCount = hesitationCount
        self.wpm = wpm
        self.expectedWPM = expectedWPM
        self.selfRating = selfRating
    }

    public var cleanLineRatio: Double {
        Double(cleanLinesCount) / Double(max(1, totalLinesCount))
    }
}

public enum ImplicitGrader {
    /// Calculate objective ReviewGrade (1..4) from keystroke telemetry.
    public static func grade(from telemetry: PracticeTelemetry) -> ReviewGrade {
        let cleanRatio = telemetry.cleanLineRatio

        // Grade 1 (Again): > 2 hints or > 3 wrong attempts / resets on the pattern
        if telemetry.hintsUsed > 2 || telemetry.wrongAttempts > 3 {
            return .again
        }

        // Using 1 or 2 hints indicates the user needed recall assistance -> Hard
        if telemetry.hintsUsed > 0 {
            return .hard
        }

        // Completed with 0 hints:
        // Grade 2 (Hard): peak hesitation (> 1.5s) or low clean line ratio (< 75%)
        if telemetry.peakHesitation > 1.5 || cleanRatio < 0.75 {
            return .hard
        }

        // Expected WPM variance check
        let isWithinWPMVariance: Bool
        if let expected = telemetry.expectedWPM, expected > 0 {
            isWithinWPMVariance = telemetry.wpm >= expected * 0.75
        } else {
            isWithinWPMVariance = true
        }

        // High fluency check for Grade 4 (Easy)
        let isHighFluency: Bool
        if let expected = telemetry.expectedWPM, expected > 0 {
            isHighFluency = telemetry.wpm >= expected * 0.90 && telemetry.peakHesitation <= 1.0
        } else {
            isHighFluency = telemetry.peakHesitation <= 1.0 && telemetry.hesitationCount == 0
        }

        // Grade 4 (Easy): 100% clean lines, zero hints, high fluency in Recall or Key Lines mode
        if cleanRatio >= 1.0 &&
            telemetry.hintsUsed == 0 &&
            telemetry.wrongAttempts == 0 &&
            (telemetry.mode == .recall || telemetry.mode == .keyLines) &&
            isHighFluency {
            return .easy
        }

        // Grade 3 (Good): Fluent recall within expected WPM variance, clean line ratio >= 85%
        if cleanRatio >= 0.85 && isWithinWPMVariance && telemetry.peakHesitation <= 1.5 {
            return .good
        }

        // Fallback for ratios between 75% and 85%, or hesitation outside good bounds
        return .hard
    }

    /// Blend objective telemetry grade with explicit user selfRating
    public static func blend(objective: ReviewGrade, selfRating: SelfRating?) -> ReviewGrade {
        guard let selfRating else { return objective }
        switch selfRating {
        case .forgot:
            return .again
        case .shaky:
            return min(objective, .hard)
        case .solid:
            if objective == .again {
                return .again
            } else if objective == .hard {
                return .hard
            } else {
                return .good
            }
        case .effortless:
            if objective == .again {
                return .again
            } else if objective == .hard {
                return .good
            } else {
                return .easy
            }
        }
    }

    /// Calculate combined grade from telemetry and optional selfRating
    public static func grade(telemetry: PracticeTelemetry) -> ReviewGrade {
        let objective = grade(from: telemetry)
        return blend(objective: objective, selfRating: telemetry.selfRating)
    }
}

// MARK: - Pattern Mastery & Spaced Repetition Record

public struct MasteryRecord: Codable, Sendable, Equatable {
    public let patternID: String
    public var level: MasteryLevel
    public var cleanLineRatio: Double
    public var consecutiveCleanSessions: Int
    public var stability: Double     // estimated memory retention stability in days
    public var difficulty: Double    // scale 1.0 (easiest) to 10.0 (hardest)
    public var lastReviewedAt: Date?
    public var nextReviewDate: Date?

    public init(patternID: String,
                level: MasteryLevel = .unstarted,
                cleanLineRatio: Double = 0.0,
                consecutiveCleanSessions: Int = 0,
                stability: Double = 1.0,
                difficulty: Double = 5.0,
                lastReviewedAt: Date? = nil,
                nextReviewDate: Date? = nil) {
        self.patternID = patternID
        self.level = level
        self.cleanLineRatio = cleanLineRatio
        self.consecutiveCleanSessions = consecutiveCleanSessions
        self.stability = max(0.1, stability)
        self.difficulty = min(10.0, max(1.0, difficulty))
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewDate = nextReviewDate
    }

    public var isDueForRecall: Bool {
        guard let nextReviewDate else { return false }
        return nextReviewDate <= Date()
    }

    public var isFadingGold: Bool {
        level == .internalized && isDueForRecall
    }

    /// Retrievability R(t, S) at current date
    public var retrievability: Double {
        retrievability(at: Date())
    }

    /// Retrievability R(t, S) at given date
    public func retrievability(at date: Date, engine: FSRSEngine = .shared) -> Double {
        guard let lastReviewedAt else { return 1.0 }
        let elapsedDays = max(0.0, date.timeIntervalSince(lastReviewedAt) / 86400.0)
        return engine.retrievability(elapsedDays: elapsedDays, stability: stability)
    }

    /// Recommended cognitive practice mode based on stability
    public var recommendedMode: PracticeMode {
        FSRSEngine.recommendedMode(for: stability)
    }
}

// MARK: - FSRS v5 Spaced Repetition Scheduler

public enum RecallDecayScheduler {
    public static func evaluate(
        patternID: String,
        currentRecord: MasteryRecord?,
        mode: PracticeMode,
        cleanLinesCount: Int,
        totalLinesCount: Int,
        hintsUsed: Int,
        selfRating: SelfRating? = nil,
        hesitationCount: Int = 0,
        peakHesitation: TimeInterval = 0.0,
        wrongAttempts: Int = 0,
        wpm: Double = 0.0,
        expectedWPM: Double? = nil,
        now: Date = Date(),
        engine: FSRSEngine = .shared
    ) -> MasteryRecord {
        let total = max(1, totalLinesCount)
        let cleanRatio = Double(cleanLinesCount) / Double(total)
        var record = currentRecord ?? MasteryRecord(patternID: patternID)

        // 1. Mastery Stage Advancement Check
        var newLevel = record.level
        switch mode {
        case .copy:
            if cleanRatio >= 0.85 && newLevel < .familiar {
                newLevel = .familiar
            }
        case .keyLines:
            if hintsUsed <= 1 && cleanRatio >= 0.70 && newLevel < .structural {
                newLevel = .structural
            }
        case .recall:
            if cleanRatio >= 0.90 && hintsUsed == 0 {
                newLevel = .internalized
            }
        }
        record.level = newLevel
        record.cleanLineRatio = cleanRatio

        // 2. Telemetry-Derived Implicit Grading
        let effectivePeakHesitation = peakHesitation > 0 ? peakHesitation : (hesitationCount > 2 ? 2.0 : 0.0)
        let telemetry = PracticeTelemetry(
            mode: mode,
            cleanLinesCount: cleanLinesCount,
            totalLinesCount: totalLinesCount,
            hintsUsed: hintsUsed,
            wrongAttempts: wrongAttempts,
            peakHesitation: effectivePeakHesitation,
            hesitationCount: hesitationCount,
            wpm: wpm,
            expectedWPM: expectedWPM,
            selfRating: selfRating
        )
        let grade = ImplicitGrader.grade(telemetry: telemetry)

        // 3. FSRS v5 State Transitions
        let isInitial = record.lastReviewedAt == nil && (currentRecord == nil || currentRecord?.stability == 1.0)

        let nextStability: Double
        let nextDifficulty: Double
        let interval: Double

        if isInitial {
            nextStability = engine.initialStability(for: grade)
            nextDifficulty = engine.initialDifficulty(for: grade)
            interval = grade == .again ? 1.0 : engine.interval(for: nextStability)
        } else {
            let elapsedDays = record.lastReviewedAt.map { max(0.0, now.timeIntervalSince($0) / 86400.0) } ?? record.stability
            let r = engine.retrievability(elapsedDays: elapsedDays, stability: record.stability)
            nextDifficulty = engine.nextDifficulty(current: record.difficulty, grade: grade)

            if grade == .again {
                nextStability = engine.nextLapseStability(stability: record.stability, difficulty: record.difficulty, retrievability: r)
                interval = 1.0
            } else {
                nextStability = engine.nextRecallStability(stability: record.stability, difficulty: record.difficulty, retrievability: r, grade: grade)
                interval = engine.interval(for: nextStability)
            }
        }

        // Consecutive clean sessions tracking
        if grade == .good || grade == .easy {
            record.consecutiveCleanSessions += 1
        } else {
            record.consecutiveCleanSessions = 0
        }

        let intervalDays = max(1, min(365, Int(interval.rounded())))
        let nextDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: now)
            ?? now.addingTimeInterval(Double(intervalDays * 86400))

        record.stability = nextStability
        record.difficulty = nextDifficulty
        record.lastReviewedAt = now
        record.nextReviewDate = nextDate

        return record
    }

    public static func evaluate(
        patternID: String,
        currentRecord: MasteryRecord?,
        telemetry: PracticeTelemetry,
        now: Date = Date(),
        engine: FSRSEngine = .shared
    ) -> MasteryRecord {
        evaluate(
            patternID: patternID,
            currentRecord: currentRecord,
            mode: telemetry.mode,
            cleanLinesCount: telemetry.cleanLinesCount,
            totalLinesCount: telemetry.totalLinesCount,
            hintsUsed: telemetry.hintsUsed,
            selfRating: telemetry.selfRating,
            hesitationCount: telemetry.hesitationCount,
            peakHesitation: telemetry.peakHesitation,
            wrongAttempts: telemetry.wrongAttempts,
            wpm: telemetry.wpm,
            expectedWPM: telemetry.expectedWPM,
            now: now,
            engine: engine
        )
    }

    public static func recommendedMode(for stability: Double) -> PracticeMode {
        FSRSEngine.recommendedMode(for: stability)
    }
}

// MARK: - Reactive Mastery Store

@MainActor
public final class MasteryStore: ObservableObject {
    public static let shared = MasteryStore()

    private let defaults: UserDefaults
    private let storageKey = "mastery.records.v1"

    @Published public private(set) var records: [String: MasteryRecord] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadRecords()
    }

    public func record(for patternID: String) -> MasteryRecord {
        records[patternID] ?? MasteryRecord(patternID: patternID)
    }

    public func level(for patternID: String) -> MasteryLevel {
        records[patternID]?.level ?? .unstarted
    }

    public func isDueForRecall(patternID: String) -> Bool {
        records[patternID]?.isDueForRecall ?? false
    }

    public var dueForRecallCount: Int {
        records.values.filter(\.isDueForRecall).count
    }

    public func dueForRecallPatternIDs() -> Set<String> {
        Set(records.values.filter(\.isDueForRecall).map(\.patternID))
    }

    public func update(record: MasteryRecord) {
        records[record.patternID] = record
        persistRecords()
    }

    private func loadRecords() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: MasteryRecord].self, from: data) else {
            return
        }
        self.records = decoded
    }

    private func persistRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
}

// MARK: - Tri-Ring / 3-Segment Mastery Glyph

public struct TriRingMasteryGlyph: View {
    public let level: MasteryLevel
    public var isDueForRecall: Bool = false
    public var size: CGFloat = 16

    public init(level: MasteryLevel, isDueForRecall: Bool = false, size: CGFloat = 16) {
        self.level = level
        self.isDueForRecall = isDueForRecall
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background track (3 faint segments)
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: size * 0.18)

            // Stage 1 (Bronze arc 0 -> 120 deg)
            if level >= .familiar {
                Circle()
                    .trim(from: 0.04, to: 0.30)
                    .stroke(MasteryLevel.familiar.color, style: StrokeStyle(lineWidth: size * 0.18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            // Stage 2 (Silver arc 120 -> 240 deg)
            if level >= .structural {
                Circle()
                    .trim(from: 0.37, to: 0.63)
                    .stroke(MasteryLevel.structural.color, style: StrokeStyle(lineWidth: size * 0.18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            // Stage 3 (Gold arc 240 -> 360 deg)
            if level >= .internalized {
                Circle()
                    .trim(from: 0.70, to: 0.96)
                    .stroke(MasteryLevel.internalized.color.opacity(isDueForRecall ? 0.45 : 1.0),
                            style: StrokeStyle(lineWidth: size * 0.18, lineCap: .round, dash: isDueForRecall ? [2, 2] : []))
                    .rotationEffect(.degrees(-90))
            }

            // Center pip for internalized
            if level == .internalized && !isDueForRecall {
                Circle()
                    .fill(MasteryLevel.internalized.color)
                    .frame(width: size * 0.32, height: size * 0.32)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(level.title) mastery\(isDueForRecall ? ", review due" : "")")
    }
}
