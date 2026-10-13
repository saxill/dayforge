import Foundation

/// The four drills. Named `DrillOperation` so it never collides with Foundation's `Operation`.
enum DrillOperation: String, CaseIterable, Identifiable {
    case add, sub, mul, div

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .add: return "+"
        case .sub: return "−"
        case .mul: return "×"
        case .div: return "÷"
        }
    }

    var title: String {
        switch self {
        case .add: return "Addition"
        case .sub: return "Subtraction"
        case .mul: return "Multiplication"
        case .div: return "Division"
        }
    }
}

/// Difficulty 1...5, from "Warm up" to "Brutal". The ranges are deliberately demanding:
/// level 5 asks for four-digit sums and two-digit by two-digit products.
enum DrillDifficulty {
    static let range = 1...5

    static func clamp(_ level: Int) -> Int { min(max(level, range.lowerBound), range.upperBound) }

    /// Inclusive operand bounds for + and −.
    static func additive(_ level: Int) -> ClosedRange<Int> {
        switch clamp(level) {
        case 1: return 2...20
        case 2: return 10...99
        case 3: return 20...199
        case 4: return 100...999
        default: return 1000...9999
        }
    }

    /// Inclusive bounds for (left, right) of × and ÷.
    static func multiplicative(_ level: Int) -> (ClosedRange<Int>, ClosedRange<Int>) {
        switch clamp(level) {
        case 1: return (2...9, 2...9)
        case 2: return (2...12, 2...9)
        case 3: return (3...19, 3...9)
        case 4: return (11...49, 3...12)
        default: return (12...99, 11...29)
        }
    }

    static func label(_ level: Int) -> String {
        switch clamp(level) {
        case 1: return "Warm up"
        case 2: return "Steady"
        case 3: return "Brisk"
        case 4: return "Hard"
        default: return "Brutal"
        }
    }
}

struct DrillProblem: Equatable {
    let operation: DrillOperation
    let question: String
    let answer: Int

    var digits: Int { String(answer).count }
}

/// A small seedable generator (mulberry32) so the Daily set is identical for everyone on a given date.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt32

    init(dateKey: String) {
        var h: UInt32 = 2_166_136_261
        for byte in dateKey.utf8 {
            h ^= UInt32(byte)
            h = h &* 16_777_619
        }
        state = h
    }

    private mutating func next32() -> UInt32 {
        state = state &+ 0x6D2B_79F5
        var t = state
        t = (t ^ (t >> 15)) &* (1 | t)
        t ^= t &+ (t ^ (t >> 7)) &* (61 | t)
        return t ^ (t >> 14)
    }

    mutating func next() -> UInt64 {
        (UInt64(next32()) << 32) | UInt64(next32())
    }
}

/// Either the system generator or the date-seeded one.
struct DrillRNG: RandomNumberGenerator {
    private var seeded: SeededRandom?
    private var system = SystemRandomNumberGenerator()

    init(seed dateKey: String? = nil) {
        if let dateKey { seeded = SeededRandom(dateKey: dateKey) }
    }

    mutating func next() -> UInt64 {
        if seeded != nil { return seeded!.next() }
        return system.next()
    }
}

enum DrillFactory {
    static func make(_ operation: DrillOperation, level: Int, using rng: inout DrillRNG) -> DrillProblem {
        switch operation {
        case .add:
            let r = DrillDifficulty.additive(level)
            let a = Int.random(in: r, using: &rng)
            let b = Int.random(in: r, using: &rng)
            return DrillProblem(operation: .add, question: "\(a) + \(b)", answer: a + b)
        case .sub:
            let r = DrillDifficulty.additive(level)
            var a = Int.random(in: r, using: &rng)
            var b = Int.random(in: r, using: &rng)
            if b > a { swap(&a, &b) }                       // never negative, so the keypad stays digit-only
            return DrillProblem(operation: .sub, question: "\(a) − \(b)", answer: a - b)
        case .mul:
            let (lr, rr) = DrillDifficulty.multiplicative(level)
            let a = Int.random(in: lr, using: &rng)
            let b = Int.random(in: rr, using: &rng)
            return DrillProblem(operation: .mul, question: "\(a) × \(b)", answer: a * b)
        case .div:
            let (qr, dr) = DrillDifficulty.multiplicative(level)
            let divisor = Int.random(in: dr, using: &rng)
            let quotient = Int.random(in: qr, using: &rng)
            return DrillProblem(operation: .div, question: "\(divisor * quotient) ÷ \(divisor)", answer: quotient)
        }
    }

    /// Random operation from the enabled set, avoiding an immediate repeat when there is a choice.
    static func next(from ops: [DrillOperation], level: Int, avoiding last: DrillOperation?, using rng: inout DrillRNG) -> DrillProblem {
        let pool = ops.isEmpty ? [DrillOperation.add] : ops
        var candidates = pool
        if pool.count > 1, let last { candidates = pool.filter { $0 != last } }
        let op = candidates.randomElement(using: &rng) ?? .add
        return make(op, level: level, using: &rng)
    }
}

enum DrillMode: String, CaseIterable, Identifiable {
    case sprint, marathon, daily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sprint: return "Sprint"
        case .marathon: return "Marathon"
        case .daily: return "Daily"
        }
    }

    var blurb: String {
        switch self {
        case .sprint: return "60 seconds. Every miss costs you two."
        case .marathon: return "20 problems, 3 lives, clock running."
        case .daily: return "15 mixed problems. Same set for everyone, all day."
        }
    }

    var icon: String {
        switch self {
        case .sprint: return "bolt.fill"
        case .marathon: return "flag.pattern.checkered"
        case .daily: return "calendar"
        }
    }

    var accent: Accent {
        switch self {
        case .sprint: return .clay
        case .marathon: return .blue
        case .daily: return .moss
        }
    }

    /// Wall-clock limit, if the mode is against the clock.
    var limit: TimeInterval? { self == .sprint ? 60 : nil }

    /// Fixed problem count, if the mode is a fixed set.
    var total: Int? {
        switch self {
        case .sprint: return nil
        case .marathon: return 20
        case .daily: return 15
        }
    }

    var lives: Int? { self == .sprint ? nil : 3 }

    /// Seconds added to the clock for a miss (Sprint only).
    var missPenalty: TimeInterval { self == .sprint ? 2 : 0 }
}

struct DrillResult: Identifiable {
    let id = UUID()
    let mode: DrillMode
    let level: Int
    let correct: Int
    let wrong: Int
    let elapsed: TimeInterval
    let ranOutOfLives: Bool
    let solveTimes: [TimeInterval]
    let misses: [Miss]
    var isPersonalBest = false

    struct Miss: Identifiable {
        let id = UUID()
        let question: String
        let answer: Int
        let typed: String
    }

    var seen: Int { correct + wrong }
    var accuracy: Double? { seen == 0 ? nil : Double(correct) / Double(seen) }
    var averageSolve: TimeInterval? { solveTimes.isEmpty ? nil : solveTimes.reduce(0, +) / Double(solveTimes.count) }
    var fastestSolve: TimeInterval? { solveTimes.min() }
}
