import SwiftUI

/// Runs one round of a drill: timing, lives, penalties and keypad input.
@MainActor
final class DrillEngine: ObservableObject {
    enum Feedback: Equatable { case idle, correct, wrong }

    let mode: DrillMode
    let ops: [DrillOperation]
    let level: Int
    let total: Int?

    @Published private(set) var problem: DrillProblem
    @Published private(set) var typed = ""
    @Published private(set) var answered = 0
    @Published private(set) var correct = 0
    @Published private(set) var wrong = 0
    @Published private(set) var livesLeft: Int
    @Published private(set) var feedback: Feedback = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isFinished = false
    @Published private(set) var runStreak = 0
    /// Bumped on every keypress and answer, used to drive haptics.
    @Published private(set) var tick = 0

    private var rng: DrillRNG
    private var startDate = Date()
    private var questionStart = Date()
    private var penalty: TimeInterval = 0
    private var isLocked = false
    private var timer: Timer?
    private var solveTimes: [TimeInterval] = []
    private var misses: [DrillResult.Miss] = []
    private var onFinish: ((DrillResult) -> Void)?

    /// Stable key for "today", shared by every device, so the Daily set matches.
    static var todayKey: String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    init(mode: DrillMode, operations: [DrillOperation], level: Int) {
        var source: DrillRNG
        let resolvedOps: [DrillOperation]
        let resolvedLevel: Int
        if mode == .daily {
            resolvedOps = DrillOperation.allCases
            resolvedLevel = 3
            source = DrillRNG(seed: DrillEngine.todayKey)
        } else {
            resolvedOps = operations.isEmpty ? [.add] : operations
            resolvedLevel = DrillDifficulty.clamp(level)
            source = DrillRNG()
        }
        let first = DrillFactory.next(from: resolvedOps, level: resolvedLevel, avoiding: nil, using: &source)

        self.mode = mode
        self.total = mode.total
        self.livesLeft = mode.lives ?? 0
        self.ops = resolvedOps
        self.level = resolvedLevel
        self.rng = source
        self.problem = first
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: Lifecycle

    func start(onFinish: @escaping (DrillResult) -> Void) {
        self.onFinish = onFinish
        startDate = Date()
        questionStart = Date()
        timer?.invalidate()
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.clockTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func abandon() {
        timer?.invalidate()
        timer = nil
        onFinish = nil
        isFinished = true
    }

    private func clockTick() {
        guard !isFinished else { return }
        elapsed = Date().timeIntervalSince(startDate) + penalty
        if let limit = mode.limit, elapsed >= limit { finish(ranOutOfLives: false) }
    }

    // MARK: Display

    var remaining: TimeInterval? { mode.limit.map { max(0, $0 - elapsed) } }

    var clockText: String {
        if let remaining { return String(format: "0:%02d", Int(ceil(remaining))) }
        let s = Int(elapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// 0...1, how full the progress bar should be.
    var progress: Double {
        if let limit = mode.limit, let remaining { return max(0, min(1, remaining / limit)) }
        guard let total else { return 0 }
        return max(0, min(1, Double(answered) / Double(total)))
    }

    // MARK: Input

    func type(_ digit: String) {
        guard !isLocked, !isFinished, typed.count < 7 else { return }
        if typed == "0" { typed = "" }
        typed += digit
        tick += 1
        if typed.count >= problem.digits { submit() }
    }

    func backspace() {
        guard !isLocked, !typed.isEmpty else { return }
        typed.removeLast()
        tick += 1
    }

    private func submit() {
        guard let value = Int(typed) else { return }
        isLocked = true
        let seconds = Date().timeIntervalSince(questionStart)
        answered += 1

        if value == problem.answer {
            correct += 1
            runStreak += 1
            solveTimes.append(seconds)
            feedback = .correct
        } else {
            wrong += 1
            runStreak = 0
            penalty += mode.missPenalty
            if mode.lives != nil { livesLeft -= 1 }
            misses.append(DrillResult.Miss(question: problem.question, answer: problem.answer, typed: typed))
            feedback = .wrong
        }
        tick += 1

        let ranOut = mode.lives != nil && livesLeft <= 0
        let doneByCount = total.map { answered >= $0 } ?? false
        let pause: UInt64 = feedback == .wrong ? 450_000_000 : 160_000_000
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: pause)
            guard !isFinished else { return }
            if ranOut || doneByCount {
                finish(ranOutOfLives: ranOut)
            } else {
                advance()
            }
        }
    }

    private func advance() {
        problem = DrillFactory.next(from: ops, level: level, avoiding: problem.operation, using: &rng)
        typed = ""
        feedback = .idle
        isLocked = false
        questionStart = Date()
    }

    private func finish(ranOutOfLives: Bool) {
        guard !isFinished else { return }
        isFinished = true
        timer?.invalidate()
        timer = nil
        elapsed = Date().timeIntervalSince(startDate) + penalty
        let result = DrillResult(mode: mode, level: level, correct: correct, wrong: wrong, elapsed: elapsed,
                                 ranOutOfLives: ranOutOfLives, solveTimes: solveTimes, misses: misses)
        onFinish?(result)
        onFinish = nil
    }
}
