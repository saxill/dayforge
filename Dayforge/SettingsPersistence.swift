import Foundation

/// Small, local-only storage for settings that are owned by this install. The widget snapshots remain
/// in the App Group, while these values are read by the app before its optional cloud state is restored.
enum DayforgeLocalStore {
    private static let defaults = UserDefaults.standard

    private static let focusDurationKey = "dayforge.focusDurationMinutes"
    private static let monthlyBudgetKey = "dayforge.monthlyBudget"
    private static let habitsKey = "dayforge.habits"
    private static let alarmKey = "dayforge.alarm"

    static var focusDurationMinutes: Int {
        let stored = defaults.object(forKey: focusDurationKey) as? Int ?? 25
        return min(120, max(5, stored))
    }

    static func saveFocusDuration(minutes: Int) {
        defaults.set(min(120, max(5, minutes)), forKey: focusDurationKey)
    }

    static var monthlyBudget: Double {
        let stored = defaults.object(forKey: monthlyBudgetKey) as? Double ?? 600
        return stored.isFinite && stored > 0 ? min(1_000_000, stored) : 600
    }

    static func saveMonthlyBudget(_ value: Double) {
        defaults.set(value, forKey: monthlyBudgetKey)
    }

    static func loadHabits() -> [Habit]? {
        guard let data = defaults.data(forKey: habitsKey) else { return nil }
        return try? JSONDecoder().decode([Habit].self, from: data)
    }

    static func saveHabits(_ habits: [Habit]) {
        guard let data = try? JSONEncoder().encode(habits) else { return }
        defaults.set(data, forKey: habitsKey)
    }

    static func loadAlarm() -> Alarm? {
        guard let data = defaults.data(forKey: alarmKey) else { return nil }
        return try? JSONDecoder().decode(Alarm.self, from: data)
    }

    static func saveAlarm(_ alarm: Alarm) {
        guard let data = try? JSONEncoder().encode(alarm) else { return }
        defaults.set(data, forKey: alarmKey)
    }
}

extension AppState {
    func persistHabits() {
        DayforgeLocalStore.saveHabits(habits)
    }

    func persistAlarm() {
        DayforgeLocalStore.saveAlarm(alarm)
    }
}
