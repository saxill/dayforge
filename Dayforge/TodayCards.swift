import SwiftUI
import UIKit

// MARK: Header and pulse

struct TodayHeader: View {
    @EnvironmentObject private var app: AppState
    var greeting: String
    var dateText: String
    var openProfile: () -> Void = {}

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateText.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Theme.inkSoft)
                Text(greeting)
                    .font(Theme.title(32))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Button(action: openProfile) {
                AvatarView(data: app.profile.avatarData, name: app.profile.name, size: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open your profile")
        }
    }
}

struct PulseCard: View {
    @EnvironmentObject private var app: AppState
    var onFocus: () -> Void = {}
    @State private var shareImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: Double(app.pulse) / 100, lineWidth: 11, tint: .white)
                    Text("\(app.pulse)")
                        .font(Theme.number(30))
                        .foregroundStyle(.white)
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Dayforge pulse")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer(minLength: 0)
                        Button(action: makeShareImage) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.white.opacity(0.16), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Share your Dayforge pulse")
                    }
                    Text(message)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(app.habitsDone) of \(app.habits.count) habits, \(app.focusMinutesToday) focus min")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                }
                Spacer(minLength: 0)
            }

            Button(action: nextMoveAction) {
                HStack(spacing: 8) {
                    Image(systemName: nextMoveIcon)
                    Text(nextMoveTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.deep)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(.white.opacity(0.92), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(nextMoveTitle)
            .accessibilityHint(nextHabit == nil ? "Opens the focus timer" : "Marks the next habit complete")
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Theme.moss, Theme.deep], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: Theme.deep.opacity(0.28), radius: 16, x: 0, y: 10)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: shareSheetPresented) {
            if let shareImage {
                PulseShareSheet(image: shareImage)
            }
        }
    }

    private var shareSheetPresented: Binding<Bool> {
        Binding(
            get: { shareImage != nil },
            set: { if !$0 { shareImage = nil } }
        )
    }

    private var nextHabit: Habit? { app.habits.first(where: { !$0.isDone }) }

    private var nextMoveTitle: String {
        if let nextHabit { return "Next: \(nextHabit.title)" }
        return "Start a focus session"
    }

    private var nextMoveIcon: String { nextHabit == nil ? "timer" : "checkmark" }

    private func nextMoveAction() {
        if let nextHabit {
            withAnimation(.snappy) { app.toggleHabit(nextHabit.id) }
        } else {
            onFocus()
        }
    }

    @MainActor
    private func makeShareImage() {
        let renderer = ImageRenderer(content: PulseArtifact(
            pulse: app.pulse,
            message: message,
            habitsDone: app.habitsDone,
            habitsTotal: app.habits.count,
            focusMinutes: app.focusMinutesToday,
            nextMove: nextMoveTitle
        ).frame(width: 1080, height: 1350))
        renderer.scale = 2
        shareImage = renderer.uiImage
    }

    private var message: String {
        switch app.pulse {
        case 0..<25: return "A calm start. One small win gets you moving."
        case 25..<60: return "Good momentum. Keep stacking the day."
        case 60..<85: return "Strong day so far. Protect your focus time."
        default: return "Everything is clicking. Nicely forged."
        }
    }
}

// MARK: Shortcuts

struct ShortcutGrid: View {
    @EnvironmentObject private var app: AppState
    var onFocus: () -> Void
    var onHabits: () -> Void
    var onExpense: () -> Void
    var onAlarm: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ShortcutCard(title: "Focus", subtitle: "\(app.focusDurationMinutes) min timer", icon: "timer", accent: .blue, action: onFocus)
            ShortcutCard(title: "Habits", subtitle: "Today's list", icon: "checkmark.circle.fill", accent: .moss, action: onHabits)
            ShortcutCard(title: "Expense", subtitle: "Log spending", icon: "creditcard.fill", accent: .clay, action: onExpense)
            ShortcutCard(title: "Alarm", subtitle: "Wake-up time", icon: "alarm.fill", accent: .yellow, action: onAlarm)
        }
    }
}

struct ShortcutCard: View {
    var title: String
    var subtitle: String
    var icon: String
    var accent: Accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconBadge(systemName: icon, accent: accent, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .dayCard(padding: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) shortcut")
        .accessibilityHint(subtitle)
    }
}

// MARK: Habits

struct HabitsCard: View {
    @EnvironmentObject private var app: AppState
    @State private var showManager = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Habits")
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if !app.habits.isEmpty {
                    Text("\(app.habitsDone) of \(app.habits.count)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                }
                Button {
                    showManager = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.moss)
                        .padding(8)
                        .background(Theme.moss.opacity(0.13), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Manage habits")
            }

            if app.habits.isEmpty {
                EmptyStateView(icon: "leaf", title: "No habits yet", message: "Add a habit and it will show up here as a daily checklist.")
            } else {
                ProgressBar(progress: app.habitProgress, tint: Theme.moss)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Habit progress")
                    .accessibilityValue("\(Int(app.habitProgress * 100)) percent")

                VStack(spacing: 4) {
                    ForEach(app.habits) { habit in
                        HabitRow(habit: habit) {
                            withAnimation(.snappy) { app.toggleHabit(habit.id) }
                        }
                    }
                }
            }
        }
        .dayCard()
        .sheet(isPresented: $showManager) {
            HabitManagerSheet(habits: app.habits) { updated in
                app.updateHabits(updated)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct HabitRow: View {
    var habit: Habit
    var toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                IconBadge(systemName: habit.icon, accent: habit.accent, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .strikethrough(habit.isDone, color: Theme.inkSoft)
                    Text("\(habit.detail) · \(habit.streak) day streak")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: habit.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(habit.isDone ? Theme.moss : Theme.inkSoft.opacity(0.5))
                    .symbolEffect(.bounce, value: habit.isDone)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(habit.title), \(habit.detail)")
        .accessibilityValue(habit.isDone ? "Done" : "Not done")
        .accessibilityHint("Double tap to mark \(habit.isDone ? "not done" : "done")")
        .accessibilityAddTraits(.isToggle)
    }
}

// MARK: Alarm

struct AlarmCard: View {
    @EnvironmentObject private var app: AppState
    @State private var showEditor = false

    var body: some View {
        let alarm = app.alarm
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Alarm")
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button {
                    showEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.yellow))
                .accessibilityHint("Changes the alarm time, label, and repeat schedule")
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(alarm.clockText)
                            .font(Theme.number(44))
                        Text(alarm.periodText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(alarm.isOn ? Theme.ink : Theme.inkSoft.opacity(0.7))

                    Text("\(alarm.label) · \(alarm.repeatText)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)

                    Label(alarm.countdownText(), systemImage: alarm.isOn ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(alarm.isOn ? Theme.yellow : Theme.inkSoft)
                        .padding(.top, 2)
                }
                Spacer()
                Toggle("Alarm", isOn: Binding(get: { app.alarm.isOn }, set: { app.setAlarm($0) }))
                    .labelsHidden()
                    .tint(Theme.yellow)
                    .accessibilityLabel("Alarm \(alarm.spokenTime), \(alarm.label)")
                    .accessibilityValue(alarm.isOn ? "On" : "Off")
            }
        }
        .dayCard()
        .opacity(alarm.isOn ? 1 : 0.78)
        .animation(.easeInOut(duration: 0.2), value: alarm.isOn)
        .sheet(isPresented: $showEditor) {
            AlarmEditorSheet(alarm: app.alarm) { updated in
                app.updateAlarm(updated)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: Spending

struct SpendingCard: View {
    @EnvironmentObject private var app: AppState
    var onAdd: () -> Void
    @State private var showBudget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("This month")
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("of \(app.money(app.monthlyBudget))")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                Button {
                    showBudget = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.clay)
                        .padding(8)
                        .background(Theme.clay.opacity(0.13), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit monthly budget")
            }

            Text(app.money(app.monthlySpend))
                .font(Theme.number(36))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
                .animation(.snappy, value: app.monthlySpend)
                .accessibilityLabel("Spent this month \(app.money(app.monthlySpend))")

            ProgressBar(progress: app.budgetProgress, tint: app.budgetProgress > 0.9 ? Theme.clay : Theme.blue)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Budget used")
                .accessibilityValue("\(Int(app.budgetProgress * 100)) percent")

            if app.recentExpenses.isEmpty {
                EmptyStateView(icon: "tray", title: "Nothing logged yet", message: "Add your first expense to start the month's total.")
            } else {
                VStack(spacing: 10) {
                    ForEach(app.recentExpenses) { expense in
                        HStack(spacing: 12) {
                            IconBadge(systemName: expense.category.icon, accent: expense.category.accent, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(expense.note.isEmpty ? expense.category.title : expense.note)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                Text(expense.category.title)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            Text(app.money(expense.amount))
                                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Theme.ink)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Button(action: onAdd) {
                Label("Add expense", systemImage: "plus")
            }
            .buttonStyle(FilledButtonStyle(tint: Theme.clay))
            .accessibilityHint("Opens a form to log an expense")
        }
        .dayCard()
        .sheet(isPresented: $showBudget) {
            BudgetSheet(currentBudget: app.monthlyBudget) { value in
                _ = app.setMonthlyBudget(value)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: Brain training and news

struct BrainTrainingCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brain training")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Sprint, Marathon and Daily drills. Up to level Brutal.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            .padding(18)
            .background(
                LinearGradient(colors: [Theme.blue, Theme.deep], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start brain training")
        .accessibilityHint("Opens the mental maths drills")
    }
}

struct NewsCard: View {
    var article: AIArticle
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TagPill(text: article.tag, accent: article.accent)
                    Spacer()
                    Text("\(article.minutes) min read")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                }
                Text(article.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Text(article.summary)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.leading)
                Label("Read the brief", systemImage: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(article.accent.color)
            }
            .dayCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI news: \(article.title)")
        .accessibilityHint("Opens the story")
    }
}
