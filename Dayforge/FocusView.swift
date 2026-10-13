import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject var timer: FocusTimer
    @State private var showBrain = false
    @State private var showDurationSettings = false

    private var ringTint: Color {
        timer.phase == .finished ? Theme.moss : Theme.blue
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                timerCard
                controls
                liveActivityControl
                BrainTrainingCard(action: { showBrain = true })
                statsCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showBrain) {
            BrainTrainingSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDurationSettings) {
            FocusDurationSheet(timer: timer) { minutes in
                _ = app.setFocusDuration(minutes: minutes)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FOCUS")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.inkSoft)
            HStack(alignment: .center, spacing: 12) {
                Text("One thing, \(app.focusDurationMinutes) minutes")
                    .font(Theme.title(30))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Button {
                    showDurationSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                        .padding(11)
                        .background(Theme.blue.opacity(0.13), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Focus timer settings")
                .accessibilityHint("Changes the focus duration")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var timerCard: some View {
        VStack(spacing: 18) {
            ZStack {
                ProgressRing(progress: timer.progress, lineWidth: 18, tint: ringTint)
                VStack(spacing: 6) {
                    if timer.phase == .finished {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.moss)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text(timer.clockText)
                        .font(.system(size: 58, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText(countsDown: true))
                    Text(timer.statusText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(timer.phase == .finished ? Theme.moss : Theme.inkSoft)
                }
            }
            .frame(width: 270, height: 270)
            .animation(.snappy, value: timer.phase)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Focus timer")
            .accessibilityValue("\(timer.remaining / 60) minutes \(timer.remaining % 60) seconds left. \(timer.statusText)")
        }
        .frame(maxWidth: .infinity)
        .dayCard(padding: 24)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if timer.phase == .running {
                Button {
                    timer.pause()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(FilledButtonStyle(tint: Theme.yellow, foreground: Theme.ink))
                .accessibilityHint("Pauses the countdown")
            } else {
                Button {
                    timer.start()
                } label: {
                    Label(startTitle, systemImage: "play.fill")
                }
                .buttonStyle(FilledButtonStyle(tint: Theme.blue))
                .accessibilityHint("Starts the \(app.focusDurationMinutes) minute countdown")
            }

            Button {
                timer.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.ink))
            .disabled(timer.phase == .idle)
            .opacity(timer.phase == .idle ? 0.45 : 1)
            .accessibilityHint("Sets the timer back to \(app.focusDurationMinutes) minutes")
        }
    }

    private var startTitle: String {
        switch timer.phase {
        case .idle: return "Start"
        case .paused: return "Resume"
        case .finished: return "Go again"
        case .running: return "Start"
        }
    }

    private var liveActivityControl: some View {
        Group {
            if timer.phase != .idle {
                Button {
                    if app.focusLiveActivityVisible {
                        app.stopFocusLiveActivity()
                    } else {
                        app.showFocusLiveActivity()
                    }
                } label: {
                    Label(app.focusLiveActivityVisible ? "Stop Live Activity" : "Show on Lock Screen",
                          systemImage: app.focusLiveActivityVisible ? "stop.circle" : "lock.iphone")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.moss))
                .accessibilityHint(app.focusLiveActivityVisible
                                   ? "Stops showing this focus timer outside the app"
                                   : "Shows this focus timer outside the app")
            }

            if let error = app.focusLiveActivityError {
                Text(error)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.clay)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Today", trailing: "Focus stats")
            HStack(spacing: 12) {
                StatTile(value: "\(app.focusSessionsToday)", label: "Sessions", icon: "checkmark.circle.fill", accent: .moss)
                StatTile(value: "\(app.focusMinutesToday)", label: "Minutes", icon: "clock.fill", accent: .blue)
                StatTile(value: "\(app.focusStreakDays)", label: "Day streak", icon: "flame.fill", accent: .clay)
            }
        }
        .dayCard()
    }
}

struct StatTile: View {
    var value: String
    var label: String
    var icon: String
    var accent: Accent

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent.color)
            Text(value)
                .font(Theme.number(26))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(accent.soft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}
