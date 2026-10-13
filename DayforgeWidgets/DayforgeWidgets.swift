import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

// The app's palette, repeated here because the widget is a separate process.
private let paper = Color(red: 0.965, green: 0.949, blue: 0.918)
private let ink = Color(red: 0.141, green: 0.149, blue: 0.169)
private let moss = Color(red: 0.404, green: 0.490, blue: 0.357)
private let clay = Color(red: 0.722, green: 0.420, blue: 0.314)
private let blue = Color(red: 0.388, green: 0.510, blue: 0.616)
private let yellow = Color(red: 0.824, green: 0.671, blue: 0.318)
private let deep = Color(red: 0.231, green: 0.286, blue: 0.247)

@main
struct DayforgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendingWidget()
        FocusWidget()
        HabitsWidget()
        AlarmWidget()
        AIBriefWidget()
        FocusLiveActivity()
    }
}

// MARK: Spending home-screen widget

struct SpendingEntry: TimelineEntry {
    var date: Date
    var snapshot: FinanceSnapshot
}

struct SpendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendingEntry {
        SpendingEntry(date: Date(), snapshot: FinanceSnapshot(monthKey: "", monthSpend: 0, todaySpend: 0, budget: 600, currencyCode: "USD"))
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendingEntry) -> Void) {
        completion(SpendingEntry(date: Date(), snapshot: FinanceStore.snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingEntry>) -> Void) {
        // The app and the intents reload the widget whenever spending changes.
        completion(Timeline(entries: [SpendingEntry(date: Date(), snapshot: FinanceStore.snapshot)], policy: .never))
    }
}

struct SpendingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayforgeSpending", provider: SpendingProvider()) { entry in
            SpendingWidgetView(snapshot: entry.snapshot)
                .containerBackground(paper, for: .widget)
        }
        .configurationDisplayName("Spending")
        .description("This month against your budget, with one-tap expenses.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SpendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: FinanceSnapshot

    var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer(minLength: 0)
                bar
                Button(intent: OpenAddExpenseIntent()) {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(clay, in: Capsule()).foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                header
                bar
                HStack(spacing: 8) {
                    ForEach([50.0, 100.0, 250.0], id: \.self) { amount in
                        Button(intent: QuickExpenseIntent(amount: amount, category: .other)) {
                            Text("+\(Int(amount))")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(moss.opacity(0.16), in: Capsule()).foregroundStyle(moss)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(intent: OpenAddExpenseIntent()) {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(clay, in: Capsule()).foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("THIS MONTH").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(ink.opacity(0.55))
            Text(snapshot.money(snapshot.monthSpend))
                .font(.system(size: family == .systemSmall ? 24 : 30, weight: .bold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.6).lineLimit(1).foregroundStyle(ink)
            Text("of \(snapshot.money(snapshot.budget)) · \(snapshot.money(snapshot.todaySpend)) today")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(ink.opacity(0.6)).lineLimit(1)
        }
    }

    private var bar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(ink.opacity(0.08))
                Capsule().fill(snapshot.progress > 0.9 ? clay : moss).frame(width: max(6, proxy.size.width * snapshot.progress))
            }
        }
        .frame(height: 8)
    }
}

// MARK: Focus home-screen widget

struct FocusEntry: TimelineEntry {
    var date: Date
    var snapshot: FocusWidgetSnapshot
}

struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        completion(FocusEntry(date: Date(), snapshot: FocusWidgetStore.snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        completion(Timeline(entries: [FocusEntry(date: Date(), snapshot: FocusWidgetStore.snapshot)], policy: .never))
    }
}

struct FocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayforgeFocus", provider: FocusProvider()) { entry in
            FocusWidgetView(snapshot: entry.snapshot)
                .containerBackground(paper, for: .widget)
        }
        .configurationDisplayName("Focus")
        .description("Your current focus timer and session status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FocusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: FocusWidgetSnapshot

    var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 6) {
                Label("Focus", systemImage: "timer")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(blue)
                Spacer(minLength: 0)
                Text(snapshot.clockText)
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
                Text(snapshot.phase.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(snapshot.phase == .finished ? moss : ink.opacity(0.62))
                ProgressView(value: snapshot.progress).tint(blue)
            }
        } else {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(ink.opacity(0.10), lineWidth: 8)
                    Circle().trim(from: 0, to: snapshot.progress)
                        .stroke(snapshot.phase == .finished ? moss : blue,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: snapshot.phase == .finished ? "checkmark" : "timer")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(snapshot.phase == .finished ? moss : blue)
                }
                .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOCUS").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(ink.opacity(0.55))
                    Text(snapshot.clockText)
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(ink)
                    Text(snapshot.status).font(.system(size: 12, design: .rounded)).foregroundStyle(ink.opacity(0.62)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: Habits home-screen widget

struct HabitsEntry: TimelineEntry {
    var date: Date
    var snapshot: HabitsWidgetSnapshot
}

struct HabitsProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitsEntry {
        HabitsEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitsEntry) -> Void) {
        completion(HabitsEntry(date: Date(), snapshot: HabitsWidgetStore.snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitsEntry>) -> Void) {
        completion(Timeline(entries: [HabitsEntry(date: Date(), snapshot: HabitsWidgetStore.snapshot)], policy: .never))
    }
}

struct HabitsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayforgeHabits", provider: HabitsProvider()) { entry in
            HabitsWidgetView(snapshot: entry.snapshot)
                .containerBackground(paper, for: .widget)
        }
        .configurationDisplayName("Habits")
        .description("A calm view of today's habit checklist.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HabitsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: HabitsWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Habits", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(moss)
                Spacer()
                Text("\(snapshot.completed)/\(snapshot.total)")
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink.opacity(0.62))
            }
            ProgressView(value: snapshot.progress).tint(moss)
            ForEach(Array(snapshot.items.prefix(family == .systemSmall ? 3 : 4))) { item in
                HStack(spacing: 7) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isDone ? moss : ink.opacity(0.35))
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(item.isDone ? ink.opacity(0.52) : ink)
                        .strikethrough(item.isDone)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            if snapshot.items.isEmpty {
                Text("No habits yet").font(.system(size: 12, design: .rounded)).foregroundStyle(ink.opacity(0.62))
            }
        }
    }
}

// MARK: Alarm home-screen widget

struct AlarmEntry: TimelineEntry {
    var date: Date
    var snapshot: AlarmWidgetSnapshot
}

struct AlarmProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlarmEntry {
        AlarmEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (AlarmEntry) -> Void) {
        completion(AlarmEntry(date: Date(), snapshot: AlarmWidgetStore.snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmEntry>) -> Void) {
        completion(Timeline(entries: [AlarmEntry(date: Date(), snapshot: AlarmWidgetStore.snapshot)], policy: .after(Date().addingTimeInterval(60))))
    }
}

struct AlarmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayforgeAlarm", provider: AlarmProvider()) { entry in
            AlarmWidgetView(snapshot: entry.snapshot)
                .containerBackground(paper, for: .widget)
        }
        .configurationDisplayName("Alarm")
        .description("Your next Dayforge wake-up.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AlarmWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: AlarmWidgetSnapshot

    var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 5) {
                Label("Alarm", systemImage: snapshot.isOn ? "alarm.fill" : "alarm")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.isOn ? yellow : ink.opacity(0.55))
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(snapshot.clockText).font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    Text(snapshot.periodText).font(.system(size: 13, weight: .bold, design: .rounded))
                }
                Text(snapshot.isOn ? snapshot.countdownText() : "Off")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(snapshot.isOn ? yellow : ink.opacity(0.58))
            }
        } else {
            HStack(spacing: 14) {
                Image(systemName: snapshot.isOn ? "alarm.fill" : "alarm")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(snapshot.isOn ? yellow : ink.opacity(0.48))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ALARM").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(ink.opacity(0.55))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(snapshot.clockText).font(.system(size: 29, weight: .bold, design: .rounded).monospacedDigit())
                        Text(snapshot.periodText).font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    Text("\(snapshot.label) · \(snapshot.repeatText)")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(ink.opacity(0.62)).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(snapshot.isOn ? snapshot.countdownText() : "Off")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(snapshot.isOn ? yellow : ink.opacity(0.58))
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

// MARK: Curated AI brief home-screen widget

struct AIBriefEntry: TimelineEntry {
    var date: Date
    var snapshot: AIBriefWidgetSnapshot
}

struct AIBriefProvider: TimelineProvider {
    func placeholder(in context: Context) -> AIBriefEntry {
        AIBriefEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (AIBriefEntry) -> Void) {
        completion(AIBriefEntry(date: Date(), snapshot: AIBriefWidgetStore.snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AIBriefEntry>) -> Void) {
        completion(Timeline(entries: [AIBriefEntry(date: Date(), snapshot: AIBriefWidgetStore.snapshot)], policy: .never))
    }
}

struct AIBriefWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayforgeAIBrief", provider: AIBriefProvider()) { entry in
            AIBriefWidgetView(snapshot: entry.snapshot)
                .containerBackground(paper, for: .widget)
        }
        .configurationDisplayName("AI Brief")
        .description("A short, curated Dayforge read.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AIBriefWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: AIBriefWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(snapshot.tag.uppercased(), systemImage: snapshot.icon)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(clay)
                Spacer()
                Text("\(snapshot.minutes) min")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.55))
            }
            Text(snapshot.title)
                .font(.system(size: family == .systemSmall ? 17 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(family == .systemSmall ? 4 : 3)
            if family == .systemMedium {
                Text(snapshot.summary)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(ink.opacity(0.65))
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            Label("Read the brief", systemImage: "arrow.up.right")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(clay)
        }
    }
}

// MARK: Focus Live Activity

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusAttributes.self) { context in
            let state = context.state
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("Focus", systemImage: state.phase == "finished" ? "checkmark.seal.fill" : "timer")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Spacer()
                    Text(state.phase == "finished" ? "Complete" : state.status)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                Text(focusTime(state.remainingSeconds))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                ProgressView(value: focusProgress(state)).tint(state.phase == "finished" ? moss : blue)
            }
            .foregroundStyle(.white)
            .padding(16)
            .activityBackgroundTint(deep)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: state.phase == "finished" ? "checkmark.seal.fill" : "timer")
                        .foregroundStyle(state.phase == "finished" ? moss : blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.phase == "finished" ? "Done" : state.status)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(focusTime(state.remainingSeconds))
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: focusProgress(state)).tint(state.phase == "finished" ? moss : blue)
                }
            } compactLeading: {
                Image(systemName: state.phase == "finished" ? "checkmark" : "timer")
                    .foregroundStyle(state.phase == "finished" ? moss : blue)
            } compactTrailing: {
                Text(focusTime(state.remainingSeconds))
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
            } minimal: {
                Image(systemName: state.phase == "finished" ? "checkmark" : "timer")
                    .foregroundStyle(state.phase == "finished" ? moss : blue)
            }
        }
    }
}

private func focusTime(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    return String(format: "%02d:%02d", safe / 60, safe % 60)
}

private func focusProgress(_ state: FocusAttributes.ContentState) -> Double {
    guard state.totalSeconds > 0 else { return 0 }
    return min(1, max(0, Double(state.totalSeconds - state.remainingSeconds) / Double(state.totalSeconds)))
}
