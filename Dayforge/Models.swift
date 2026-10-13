import Foundation

struct Habit: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var detail: String
    var icon: String
    var accent: Accent
    var streak: Int
    var isDone: Bool
}

struct Alarm: Hashable, Codable {
    var hour: Int
    var minute: Int
    var label: String
    var repeatText: String
    var isOn: Bool

    /// "6:30" style text without the day period.
    var clockText: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d", h, minute)
    }

    var periodText: String { hour < 12 ? "AM" : "PM" }

    var spokenTime: String { "\(clockText) \(periodText)" }

    /// "Rings in 7h 12m" for the next occurrence, or "Off".
    func countdownText(from now: Date = Date(), calendar: Calendar = .current) -> String {
        guard isOn else { return "Off" }
        var parts = DateComponents()
        parts.hour = hour
        parts.minute = minute
        guard let next = calendar.nextDate(after: now, matching: parts, matchingPolicy: .nextTime) else { return "On" }
        let minutes = max(1, Int(next.timeIntervalSince(now) / 60))
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "Rings in \(m)m" }
        return "Rings in \(h)h \(m)m"
    }
}

enum AlarmRepeatOption: String, CaseIterable, Identifiable, Hashable {
    case everyDay
    case weekdays
    case weekends
    case once

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyDay: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .once: return "Once"
        }
    }

    init(repeatText: String) {
        switch repeatText.lowercased() {
        case "mon to fri", "weekdays": self = .weekdays
        case "weekends": self = .weekends
        case "once": self = .once
        default: self = .everyDay
        }
    }
}

enum ExpenseCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case food, transport, home, fun, health, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "Food"
        case .transport: return "Transport"
        case .home: return "Home"
        case .fun: return "Fun"
        case .health: return "Health"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "tram.fill"
        case .home: return "house.fill"
        case .fun: return "popcorn.fill"
        case .health: return "cross.case.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var accent: Accent {
        switch self {
        case .food: return .clay
        case .transport: return .blue
        case .home: return .moss
        case .fun: return .yellow
        case .health: return .moss
        case .other: return .blue
        }
    }
}

struct Expense: Identifiable, Hashable, Codable {
    let id: UUID
    var amount: Double
    var category: ExpenseCategory
    var note: String
    var date: Date

    init(id: UUID = UUID(), amount: Double, category: ExpenseCategory, note: String = "", date: Date = Date()) {
        self.id = id
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
    }
}

struct AIArticle: Identifiable, Hashable {
    let id: String
    var tag: String
    var title: String
    var summary: String
    var paragraphs: [String]
    var minutes: Int
    var accent: Accent
    var icon: String
}

enum MangaArtStyle: String, CaseIterable, Hashable {
    case lanternHollow, tideAndTinder, quietRail, glassOrchard, emberParade, paperMoon
}

struct Manga: Identifiable, Hashable {
    let id: String
    var title: String
    var author: String
    var genre: String
    /// Latest chapter number. Fractional for extras, e.g. 170.5.
    var chapters: Double
    var status: String
    var blurb: String
    var chapterTitles: [String]
    var art: MangaArtStyle
    /// Set for series that came from a backup: the real cover image and where it was tracked.
    var coverData: Data? = nil
    var source: String? = nil
    var addedAt: Date? = nil
    var latestAt: Date? = nil
    /// This series' own page on its source site, when the backup had enough to build it.
    var pageURL: String? = nil

    var isImported: Bool { source != nil }
}

/// "21" for whole chapters, "170.5" for extras.
func chapterText(_ value: Double) -> String {
    value.rounded() == value ? String(Int(value)) : String(value)
}

enum LibraryStatus: String, CaseIterable, Identifiable, Hashable {
    case reading, planned, completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reading: return "Reading"
        case .planned: return "Plan to read"
        case .completed: return "Completed"
        }
    }

    var icon: String {
        switch self {
        case .reading: return "book.fill"
        case .planned: return "bookmark.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }

    var accent: Accent {
        switch self {
        case .reading: return .clay
        case .planned: return .blue
        case .completed: return .moss
        }
    }
}

struct ChapterUpdate: Identifiable, Hashable {
    var id: String { "\(mangaID)-\(chapter)" }
    var mangaID: String
    var chapter: Double
    var title: String
    var hoursAgo: Int
    /// The real update time for imported series.
    var date: Date? = nil
}

/// A PDF or CBZ you added to a series. `stored` is the file name inside the app's Files folder.
struct LocalChapter: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var stored: String

    var isPDF: Bool { stored.lowercased().hasSuffix(".pdf") }
}
