import Foundation

/// Local, in-memory sample content. Everything here is invented for Dayforge.
enum SampleData {
    static let habits: [Habit] = [
        Habit(id: "water", title: "Drink water", detail: "8 glasses", icon: "drop.fill", accent: .blue, streak: 0, isDone: false),
        Habit(id: "walk", title: "Morning walk", detail: "20 minutes", icon: "figure.walk", accent: .moss, streak: 0, isDone: false),
        Habit(id: "read", title: "Read ten pages", detail: "Any book", icon: "book.fill", accent: .clay, streak: 0, isDone: false),
        Habit(id: "journal", title: "Evening journal", detail: "Three lines", icon: "pencil.line", accent: .yellow, streak: 0, isDone: false)
    ]

    static let alarm = Alarm(hour: 6, minute: 30, label: "Weekday wake-up", repeatText: "Mon to Fri", isOn: true)

    /// Expenses an earlier build shipped as demo data. Only used to clear them from existing installs.
    static let retiredDemoExpenses: [(amount: Double, note: String)] = [
        (42.50, "Groceries"), (18.00, "Metro card top-up"), (96.40, "Electricity"),
        (24.90, "Movie night"), (31.20, "Pharmacy"), (12.75, "Lunch")
    ]

    static let articles: [AIArticle] = [
        AIArticle(
            id: "small-models",
            tag: "On-device",
            title: "Small models are getting good enough to live on your phone",
            summary: "Compact language models now handle summaries and quick replies without a network round trip.",
            paragraphs: [
                "A quiet shift is under way in how assistants are built. Instead of sending every request to a data centre, more of the everyday work, such as summarising a note or drafting a short reply, can run on the device in your hand.",
                "The trade is simple. A smaller model knows less about the world, but it answers instantly, works offline and keeps your text on the phone. For many daily tasks that is the better deal.",
                "Expect the next wave of apps to mix both: a local model for speed and privacy, and a larger remote model only when a question really needs it."
            ],
            minutes: 3, accent: .moss, icon: "iphone.gen3"
        ),
        AIArticle(
            id: "agents-chores",
            tag: "Agents",
            title: "Agents move from demos to boring, useful chores",
            summary: "The most useful AI helpers are the ones that quietly finish small, repetitive jobs.",
            paragraphs: [
                "The flashy agent demos get the attention, but the products people keep using do dull work: filing receipts, renaming files, drafting the weekly update.",
                "What makes these helpers stick is a clear boundary. They ask before doing anything that cannot be undone, and they show their work so a person can check it in seconds.",
                "If you are building one, start with a task you already do every week and make that single task reliable."
            ],
            minutes: 4, accent: .clay, icon: "gearshape.2.fill"
        ),
        AIArticle(
            id: "search-habit",
            tag: "Everyday AI",
            title: "How people are changing the way they search",
            summary: "Plain-language questions are replacing keyword lists, and people expect an answer, not ten links.",
            paragraphs: [
                "More people now type a full question and expect a direct answer. That changes what a good result looks like: short, sourced and easy to double-check.",
                "It also raises the bar for trust. A confident answer with no source is easy to believe and hard to verify, so good tools show where each claim came from.",
                "A useful habit: when an answer matters, open the source it points to before you act on it."
            ],
            minutes: 3, accent: .blue, icon: "magnifyingglass"
        ),
        AIArticle(
            id: "study-buddy",
            tag: "Learning",
            title: "A study buddy that asks you questions back",
            summary: "Tutoring tools work best when they quiz you instead of simply explaining.",
            paragraphs: [
                "Reading an explanation feels productive, but recalling it is what makes it stay. The better study tools turn that around and ask you the question first.",
                "Short, spaced quizzes beat long sessions. Five minutes a day with a tool that adapts to what you got wrong is worth more than a weekend cram.",
                "Pair it with a focus timer and a quiet room, and the whole loop fits inside one pomodoro."
            ],
            minutes: 2, accent: .yellow, icon: "brain.head.profile"
        )
    ]

    /// A date inside the current month, clamped to today so sample data never lands in the future.
    private static func thisMonth(day: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var parts = calendar.dateComponents([.year, .month], from: now)
        parts.day = min(day, calendar.component(.day, from: now))
        parts.hour = 12
        return calendar.date(from: parts) ?? now
    }
}
