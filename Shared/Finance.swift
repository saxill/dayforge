import Foundation
import AppIntents
import WidgetKit

/// Shared by the app, the widget and the intents: the App Group both processes can read and write.
let financeGroup = "group.com.omnirush.dayforge"

enum FinanceCategory: String, AppEnum, CaseIterable {
    case food, transport, home, fun, health, other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var caseDisplayRepresentations: [FinanceCategory: DisplayRepresentation] = [
        .food: "Food", .transport: "Transport", .home: "Home", .fun: "Fun", .health: "Health", .other: "Other"
    ]
}

/// What the spending widget and intents need to draw, written by the app after every change.
struct FinanceSnapshot: Codable, Equatable {
    var monthKey: String
    var monthSpend: Double
    var todaySpend: Double
    var budget: Double
    var currencyCode: String

    static let empty = FinanceSnapshot(monthKey: "", monthSpend: 0, todaySpend: 0, budget: 600,
                                       currencyCode: Locale.current.currency?.identifier ?? "USD")

    func money(_ value: Double) -> String { value.formatted(.currency(code: currencyCode)) }
    var progress: Double { budget <= 0 ? 0 : min(1, monthSpend / budget) }
}

/// An expense logged by a shortcut or the widget while the app was closed. The app folds these in when it opens.
struct PendingExpense: Codable, Identifiable {
    var id: String
    var amount: Double
    var category: String
    var note: String
    var date: Date
}

enum FinanceStore {
    private static var defaults: UserDefaults { UserDefaults(suiteName: financeGroup) ?? .standard }

    static func monthKey(_ date: Date = Date()) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }

    static var snapshot: FinanceSnapshot {
        get {
            guard let data = defaults.data(forKey: "snapshot"), let value = try? JSONDecoder().decode(FinanceSnapshot.self, from: data) else { return .empty }
            // A new month starts at zero even before the app opens.
            if value.monthKey != monthKey() { var fresh = value; fresh.monthKey = monthKey(); fresh.monthSpend = 0; fresh.todaySpend = 0; return fresh }
            return value
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "snapshot") }
    }

    static var pending: [PendingExpense] {
        get { defaults.data(forKey: "pending").flatMap { try? JSONDecoder().decode([PendingExpense].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "pending") }
    }

    static var openAddRequested: Bool {
        get { defaults.bool(forKey: "openAdd") }
        set { defaults.set(newValue, forKey: "openAdd") }
    }

    /// Queues the expense and bumps the shown totals straight away.
    @discardableResult
    static func log(amount: Double, category: FinanceCategory, note: String) -> FinanceSnapshot {
        var list = pending
        list.append(PendingExpense(id: UUID().uuidString, amount: amount, category: category.rawValue, note: note, date: Date()))
        pending = list
        var current = snapshot
        current.monthSpend += amount
        current.todaySpend += amount
        snapshot = current
        WidgetCenter.shared.reloadAllTimelines()
        return current
    }

    static func takePending() -> [PendingExpense] {
        let list = pending
        pending = []
        return list
    }
}

// MARK: Intents

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an expense"
    static var description = IntentDescription("Adds an expense to Dayforge.")

    @Parameter(title: "Amount") var amount: Double
    @Parameter(title: "Category", default: .other) var category: FinanceCategory
    @Parameter(title: "Note") var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) for \(\.$category)") { \.$note }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0, amount < 10_000_000 else { throw $amount.needsValueError("Enter an amount above zero.") }
        let rounded = (amount * 100).rounded() / 100
        let s = FinanceStore.log(amount: rounded, category: category, note: (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        return .result(dialog: "Logged \(s.money(rounded)) for \(FinanceCategory.caseDisplayRepresentations[category].map { String(localized: $0.title) } ?? "Other"). \(s.money(s.monthSpend)) of \(s.money(s.budget)) this month.")
    }
}

struct SpentThisMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "How much have I spent"
    static var description = IntentDescription("Tells you this month's spending in Dayforge.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let s = FinanceStore.snapshot
        let left = s.budget - s.monthSpend
        let tail = left >= 0 ? "\(s.money(left)) left." : "\(s.money(-left)) over budget."
        return .result(dialog: "You've spent \(s.money(s.monthSpend)) of \(s.money(s.budget)) this month, \(s.money(s.todaySpend)) today. \(tail)")
    }
}

/// Used by the widget's quick buttons.
struct QuickExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick expense"
    static var isDiscoverable = false

    @Parameter(title: "Amount") var amount: Double
    @Parameter(title: "Category") var category: FinanceCategory

    init() {}
    init(amount: Double, category: FinanceCategory) { self.amount = amount; self.category = category }

    func perform() async throws -> some IntentResult {
        _ = FinanceStore.log(amount: amount, category: category, note: "")
        return .result()
    }
}

struct OpenAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add an expense"
    static var openAppWhenRun = true
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        FinanceStore.openAddRequested = true
        return .result()
    }
}
