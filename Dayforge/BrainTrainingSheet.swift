import SwiftUI

/// Brain training: Reckon-grade mental maths. Home (mode, level, operations) -> round -> result.
struct BrainTrainingSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case home
        case playing
        case result(DrillResult)
    }

    @State private var phase: Phase = .home
    @State private var engine: DrillEngine?
    @State private var lastMode: DrillMode = .sprint
    @State private var lastOps: [DrillOperation] = DrillOperation.allCases
    @State private var lastLevel = 3

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch phase {
            case .home:
                DrillHomeView(start: begin, close: { dismiss() })
            case .playing:
                if let engine {
                    DrillGameView(engine: engine, quit: quit)
                }
            case .result(let result):
                DrillResultView(result: result,
                                again: { begin(result.mode, lastOps, lastLevel) },
                                done: { phase = .home })
            }
        }
        .animation(.snappy, value: phaseKey)
        .interactiveDismissDisabled(isPlaying)
    }

    private var phaseKey: Int {
        switch phase {
        case .home: return 0
        case .playing: return 1
        case .result: return 2
        }
    }

    private var isPlaying: Bool {
        if case .playing = phase { return true }
        return false
    }

    private func begin(_ mode: DrillMode, _ ops: [DrillOperation], _ level: Int) {
        lastMode = mode
        lastOps = ops
        lastLevel = level
        let round = DrillEngine(mode: mode, operations: ops, level: level)
        engine = round
        phase = .playing
        round.start { result in
            let scored = app.record(result)
            engine = nil
            phase = .result(scored)
        }
    }

    private func quit() {
        engine?.abandon()
        engine = nil
        phase = .home
    }
}

// MARK: Home

struct DrillHomeView: View {
    @EnvironmentObject private var app: AppState
    var start: (DrillMode, [DrillOperation], Int) -> Void
    var close: () -> Void

    @State private var level = 3
    @State private var ops: Set<DrillOperation> = Set(DrillOperation.allCases)

    private var chosenOps: [DrillOperation] { DrillOperation.allCases.filter { ops.contains($0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BRAIN TRAINING")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(Theme.inkSoft)
                        Text("Do the sum. Fast.")
                            .font(Theme.title(30))
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 38, height: 38)
                            .background(Theme.ink.opacity(0.08), in: Circle())
                    }
                    .accessibilityLabel("Close brain training")
                }

                levelPicker
                operationPicker

                VStack(spacing: 12) {
                    ForEach(DrillMode.allCases) { mode in
                        ModeCard(mode: mode, best: app.bestScore(mode, level: level)) {
                            start(mode, chosenOps, level)
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Difficulty")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Text(DrillDifficulty.label(level))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.clay)
            }
            HStack(spacing: 8) {
                ForEach(DrillDifficulty.range, id: \.self) { value in
                    Button {
                        level = value
                    } label: {
                        Text("\(value)")
                            .font(Theme.number(20))
                            .foregroundStyle(level == value ? .white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(level == value ? Theme.ink : Theme.ink.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Level \(value), \(DrillDifficulty.label(value))")
                    .accessibilityAddTraits(level == value ? [.isSelected] : [])
                }
            }
            Text("Daily always uses level 3 with every operation.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var operationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Operations")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                ForEach(DrillOperation.allCases) { op in
                    Button {
                        toggle(op)
                    } label: {
                        Text(op.symbol)
                            .font(Theme.number(26))
                            .foregroundStyle(ops.contains(op) ? .white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(ops.contains(op) ? Theme.moss : Theme.ink.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(op.title)
                    .accessibilityAddTraits(ops.contains(op) ? [.isSelected] : [])
                }
            }
        }
    }

    /// At least one operation always stays on.
    private func toggle(_ op: DrillOperation) {
        if ops.contains(op) {
            if ops.count > 1 { ops.remove(op) }
        } else {
            ops.insert(op)
        }
    }
}

struct ModeCard: View {
    var mode: DrillMode
    var best: Int?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBadge(systemName: mode.icon, accent: mode.accent, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(mode.blurb)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(best.map(String.init) ?? "–")
                        .font(Theme.number(24))
                        .foregroundStyle(mode.accent.color)
                    Text("BEST")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .dayCard(padding: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.title). \(mode.blurb)")
        .accessibilityValue(best.map { "Best score \($0)" } ?? "No score yet")
    }
}

// MARK: Game

struct DrillGameView: View {
    @ObservedObject var engine: DrillEngine
    var quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ProgressBar(progress: engine.progress, tint: engine.mode.accent.color, height: 8)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                Text(engine.problem.question)
                    .font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("Solve \(engine.problem.question)")

                Text(engine.typed.isEmpty ? "?" : engine.typed)
                    .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(engine.typed.isEmpty ? Theme.inkSoft.opacity(0.35) : answerColor)
                    .frame(height: 64)
                    .accessibilityLabel("Your answer \(engine.typed)")

                if engine.runStreak >= 3 {
                    Label("\(engine.runStreak) in a row", systemImage: "flame.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.clay)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .animation(.snappy, value: engine.runStreak >= 3)

            Spacer(minLength: 0)

            DrillKeypad(type: engine.type, backspace: engine.backspace)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
        .background(feedbackBackground.ignoresSafeArea())
        .animation(.easeOut(duration: 0.15), value: engine.feedback)
        .sensoryFeedback(.impact(weight: .light), trigger: engine.tick)
        .sensoryFeedback(.success, trigger: engine.correct)
        .sensoryFeedback(.error, trigger: engine.wrong)
    }

    private var topBar: some View {
        HStack {
            Button(action: quit) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.ink.opacity(0.08), in: Circle())
            }
            .accessibilityLabel("Quit round")

            Spacer()

            Text(engine.clockText)
                .font(Theme.number(28))
                .foregroundStyle(timeIsLow ? Theme.clay : Theme.ink)
                .accessibilityLabel("Time \(engine.clockText)")

            Spacer()

            if engine.mode.lives != nil {
                HStack(spacing: 4) {
                    ForEach(0..<(engine.mode.lives ?? 0), id: \.self) { index in
                        Image(systemName: index < engine.livesLeft ? "heart.fill" : "heart")
                            .foregroundStyle(Theme.clay)
                    }
                }
                .accessibilityLabel("\(engine.livesLeft) lives left")
            } else {
                Text("\(engine.correct)")
                    .font(Theme.number(22))
                    .foregroundStyle(Theme.moss)
                    .frame(minWidth: 38)
                    .accessibilityLabel("\(engine.correct) correct")
            }
        }
    }

    private var timeIsLow: Bool {
        guard let remaining = engine.remaining else { return false }
        return remaining <= 10
    }

    private var answerColor: Color {
        switch engine.feedback {
        case .idle: return Theme.ink
        case .correct: return Theme.moss
        case .wrong: return Theme.clay
        }
    }

    private var feedbackBackground: Color {
        switch engine.feedback {
        case .idle: return Theme.background
        case .correct: return Theme.moss.opacity(0.12)
        case .wrong: return Theme.clay.opacity(0.14)
        }
    }
}

struct DrillKeypad: View {
    var type: (String) -> Void
    var backspace: () -> Void

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]
    private let keyHeight: CGFloat = 76

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
            HStack(spacing: 10) {
                // A fixed-height spacer: a bare Color.clear would grow vertically and shove this row away from the rest.
                Color.clear.frame(maxWidth: .infinity).frame(height: keyHeight)
                keyButton("0")
                Button(action: backspace) {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: keyHeight)
                        .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            }
        }
    }

    private func keyButton(_ key: String) -> some View {
        Button {
            type(key)
        } label: {
            Text(key)
                .font(Theme.number(34))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: keyHeight)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key)
    }
}

// MARK: Result

struct DrillResultView: View {
    var result: DrillResult
    var again: () -> Void
    var done: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TagPill(text: "\(result.mode.title) · \(DrillDifficulty.label(result.level))", accent: result.mode.accent)
                        if result.isPersonalBest {
                            TagPill(text: "New best", accent: .yellow)
                        }
                    }
                    Text("\(result.correct) correct")
                        .font(Theme.title(40))
                        .foregroundStyle(Theme.ink)
                    Text(headline)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.top, 12)
                .accessibilityElement(children: .combine)

                HStack(spacing: 12) {
                    StatTile(value: accuracyText, label: "Accuracy", icon: "scope", accent: .moss)
                    StatTile(value: secondsText(result.averageSolve), label: "Avg solve", icon: "gauge.with.dots.needle.50percent", accent: .blue)
                    StatTile(value: secondsText(result.fastestSolve), label: "Fastest", icon: "bolt.fill", accent: .yellow)
                }

                if !result.misses.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Misses", trailing: "\(result.misses.count)")
                        ForEach(result.misses) { miss in
                            HStack {
                                Text(miss.question)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("you: \(miss.typed)")
                                    .font(.system(size: 13, design: .rounded).monospacedDigit())
                                    .foregroundStyle(Theme.clay)
                                Text("= \(miss.answer)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(Theme.moss)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .dayCard()
                }

                Button(action: again) {
                    Label("Play again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(FilledButtonStyle(tint: result.mode.accent.color))

                Button("Back to drills", action: done)
                    .buttonStyle(SoftButtonStyle(tint: Theme.ink))
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var headline: String {
        if result.ranOutOfLives { return "Out of lives after \(result.seen) problems." }
        switch result.mode {
        case .sprint: return "\(result.wrong) misses cost \(result.wrong * 2) seconds."
        case .marathon, .daily: return "Finished in \(timeText(result.elapsed))."
        }
    }

    private var accuracyText: String {
        guard let accuracy = result.accuracy else { return "–" }
        return "\(Int((accuracy * 100).rounded()))%"
    }

    private func secondsText(_ value: TimeInterval?) -> String {
        guard let value else { return "–" }
        return String(format: "%.1fs", value)
    }

    private func timeText(_ value: TimeInterval) -> String {
        let s = Int(value)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
