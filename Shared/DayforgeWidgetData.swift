import Foundation

// These snapshots deliberately use only Codable value types. The widget extension can read them safely
// from the App Group without importing AppState, FocusTimer, Theme, or any other app-only type.

enum FocusWidgetPhase: String, Codable, Hashable {
    case idle
    case running
    case paused
    case finished

    var title: String {
        switch self {
        case .idle: return "Ready"
        case .running: return "In focus"
        case .paused: return "Paused"
        case .finished: return "Complete"
        }
    }
}

struct FocusWidgetSnapshot: Codable, Equatable {
    var remainingSeconds: Int
    var totalSeconds: Int
    var phase: FocusWidgetPhase
    var status: String

    static let empty = FocusWidgetSnapshot(remainingSeconds: 25 * 60,
                                           totalSeconds: 25 * 60,
                                           phase: .idle,
                                           status: "Ready when you are")

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, Double(totalSeconds - remainingSeconds) / Double(totalSeconds)))
    }

    var clockText: String {
        let seconds = max(0, remainingSeconds)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct HabitWidgetItem: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var icon: String
    var accent: String
    var streak: Int
    var isDone: Bool
}

struct HabitsWidgetSnapshot: Codable, Equatable {
    var completed: Int
    var total: Int
    var items: [HabitWidgetItem]

    static let empty = HabitsWidgetSnapshot(completed: 0, total: 0, items: [])

    var progress: Double {
        total == 0 ? 0 : min(1, max(0, Double(completed) / Double(total)))
    }
}

struct AlarmWidgetSnapshot: Codable, Equatable {
    var hour: Int
    var minute: Int
    var label: String
    var repeatText: String
    var isOn: Bool

    static let empty = AlarmWidgetSnapshot(hour: 6, minute: 30, label: "Wake-up", repeatText: "Every day", isOn: false)

    var clockText: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d", h, minute)
    }

    var periodText: String { hour < 12 ? "AM" : "PM" }

    func countdownText(from now: Date = Date(), calendar: Calendar = .current) -> String {
        guard isOn else { return "Off" }
        var parts = DateComponents()
        parts.hour = hour
        parts.minute = minute
        guard let next = calendar.nextDate(after: now, matching: parts, matchingPolicy: .nextTime) else { return "On" }
        let minutes = max(1, Int(next.timeIntervalSince(now) / 60))
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "Rings in \(remainder)m" }
        return "Rings in \(hours)h \(remainder)m"
    }
}

struct AIBriefWidgetSnapshot: Codable, Equatable {
    var tag: String
    var title: String
    var summary: String
    var minutes: Int
    var icon: String

    static let empty = AIBriefWidgetSnapshot(tag: "Daily brief",
                                             title: "A useful idea for today",
                                             summary: "Open Dayforge for a short, curated read.",
                                             minutes: 3,
                                             icon: "sparkles")
}

private enum DayforgeWidgetStorage {
    static let defaults = UserDefaults(suiteName: "group.com.omnirush.dayforge") ?? .standard

    static func read<Value: Decodable>(_ type: Value.Type, key: String, fallback: Value) -> Value {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(type, from: data) else { return fallback }
        return value
    }

    static func write<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}

enum FocusWidgetStore {
    static var snapshot: FocusWidgetSnapshot {
        get { DayforgeWidgetStorage.read(FocusWidgetSnapshot.self, key: "focusWidgetSnapshot", fallback: .empty) }
        set { DayforgeWidgetStorage.write(newValue, key: "focusWidgetSnapshot") }
    }
}

enum HabitsWidgetStore {
    static var snapshot: HabitsWidgetSnapshot {
        get { DayforgeWidgetStorage.read(HabitsWidgetSnapshot.self, key: "habitsWidgetSnapshot", fallback: .empty) }
        set { DayforgeWidgetStorage.write(newValue, key: "habitsWidgetSnapshot") }
    }
}

enum AlarmWidgetStore {
    static var snapshot: AlarmWidgetSnapshot {
        get { DayforgeWidgetStorage.read(AlarmWidgetSnapshot.self, key: "alarmWidgetSnapshot", fallback: .empty) }
        set { DayforgeWidgetStorage.write(newValue, key: "alarmWidgetSnapshot") }
    }
}

enum AIBriefWidgetStore {
    static var snapshot: AIBriefWidgetSnapshot {
        get { DayforgeWidgetStorage.read(AIBriefWidgetSnapshot.self, key: "aiBriefWidgetSnapshot", fallback: .empty) }
        set { DayforgeWidgetStorage.write(newValue, key: "aiBriefWidgetSnapshot") }
    }
}
