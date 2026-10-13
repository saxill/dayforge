import SwiftUI

/// A real countdown driven by `Timer`. Idle, running, paused and finished are explicit states.
@MainActor
final class FocusTimer: ObservableObject {
    enum Phase: Equatable {
        case idle, running, paused, finished
    }

    @Published private(set) var totalSeconds: Int
    @Published private(set) var remaining: Int
    @Published private(set) var phase: Phase = .idle

    /// Called once when a session reaches zero.
    var onComplete: (() -> Void)?
    /// Called after a start, pause, reset, duration change, or countdown tick.
    var onStateChange: (() -> Void)?
    /// Called when a new session starts or a paused session resumes.
    var onStart: (() -> Void)?

    private var timer: Timer?

    init(minutes: Int = 25) {
        totalSeconds = minutes * 60
        remaining = minutes * 60
    }

    deinit {
        timer?.invalidate()
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remaining) / Double(totalSeconds)
    }

    var clockText: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    var statusText: String {
        switch phase {
        case .idle: return "Ready when you are"
        case .running: return "Stay with one thing"
        case .paused: return "Paused"
        case .finished: return "Session complete"
        }
    }

    func start() {
        if phase == .finished { reset() }
        guard phase != .running else { return }
        onStart?()
        phase = .running
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        onStateChange?()
    }

    func pause() {
        guard phase == .running else { return }
        timer?.invalidate()
        timer = nil
        phase = .paused
        onStateChange?()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        remaining = totalSeconds
        phase = .idle
        onStateChange?()
    }

    /// Changes the length of the next session. A running session must be paused first.
    @discardableResult
    func setDuration(minutes: Int) -> Bool {
        guard phase != .running, (5...120).contains(minutes) else { return false }
        timer?.invalidate()
        timer = nil
        totalSeconds = minutes * 60
        remaining = totalSeconds
        phase = .idle
        onStateChange?()
        return true
    }

    private func tick() {
        guard phase == .running else { return }
        remaining = max(0, remaining - 1)
        if remaining == 0 {
            timer?.invalidate()
            timer = nil
            phase = .finished
            onStateChange?()
            onComplete?()
        } else {
            onStateChange?()
        }
    }
}
