import AppIntents

/// Siri phrases and Shortcuts-app tiles for the finance intents.
struct DayforgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogExpenseIntent(), phrases: [
            "Log an expense in \(.applicationName)",
            "Add spending to \(.applicationName)"
        ], shortTitle: "Log expense", systemImageName: "creditcard.fill")
        AppShortcut(intent: SpentThisMonthIntent(), phrases: [
            "How much have I spent in \(.applicationName)",
            "My spending in \(.applicationName)"
        ], shortTitle: "Spent this month", systemImageName: "chart.bar.fill")
    }
}
