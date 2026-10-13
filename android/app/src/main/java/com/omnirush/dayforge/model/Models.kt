package com.omnirush.dayforge.model

import kotlinx.serialization.Serializable

@Serializable
data class Habit(
    val id: String,
    val title: String,
    val detail: String,
    val icon: String,
    val accent: String,
    val streak: Int = 0,
    val isDone: Boolean = false,
)

@Serializable
data class Expense(
    val id: String,
    val amount: Double,
    val category: String,
    val note: String = "",
    val epochMillis: Long,
)

@Serializable
data class Article(
    val id: String,
    val tag: String,
    val title: String,
    val summary: String,
    val body: String,
    val minutes: Int,
)

@Serializable
data class Manga(
    val id: String,
    val title: String,
    val author: String,
    val genre: String,
    val chapters: Int,
    val status: String,
    val blurb: String,
    val progress: Int = 0,
    val libraryStatus: String? = null,
    val sourceUrl: String? = null,
)

@Serializable
data class MotivationHistoryEntry(
    val date: String,
    val pulse: Int,
    val habitsDone: Int,
    val habitsTotal: Int,
    val focusMinutes: Int,
    val focusStreakDays: Int,
)

@Serializable
data class MotivationSummary(
    val userId: String,
    val name: String,
    val pulse: Int,
    val habitsDone: Int,
    val habitsTotal: Int,
    val focusMinutes: Int,
    val focusStreakDays: Int,
    val checkedInDate: String? = null,
    val updatedAt: Double = 0.0,
    val history: List<MotivationHistoryEntry> = emptyList(),
)

@Serializable
data class PairPayload(
    val id: String,
    val status: String,
    val code: String? = null,
    val partnerName: String? = null,
    val partnerUserId: String? = null,
    val createdAt: Double = 0.0,
)

@Serializable
data class LatestNudge(
    val fromName: String,
    val message: String,
    val createdAt: Double,
)

data class PairState(
    val pair: PairPayload?,
    val summary: MotivationSummary,
    val partner: MotivationSummary? = null,
    val latestNudge: LatestNudge? = null,
)

@Serializable
data class AlarmSettings(
    val hour: Int = 7,
    val minute: Int = 30,
    val label: String = "Start gently",
    val repeatText: String = "Every day",
    val isOn: Boolean = true,
)

@Serializable
data class ProfileSettings(
    val name: String = "",
    val theme: String = "linen",
    val showHabits: Boolean = true,
    val showAlarm: Boolean = true,
    val showSpending: Boolean = true,
    val showBrain: Boolean = true,
    val showBrief: Boolean = true,
)

@Serializable
data class AppData(
    val profile: ProfileSettings = ProfileSettings(),
    val habits: List<Habit> = SampleData.habits,
    val expenses: List<Expense> = emptyList(),
    val alarm: AlarmSettings = AlarmSettings(),
    val focusDurationMinutes: Int = 25,
    val focusSessionsToday: Int = 0,
    val focusMinutesToday: Int = 0,
    val focusStreakDays: Int = 0,
    val monthlyBudget: Double = 300.0,
    val manga: List<Manga> = SampleData.manga,
    val motivationHistory: List<MotivationHistoryEntry> = emptyList(),
)

object SampleData {
    val habits = listOf(
        Habit("water", "Hydrate", "A glass before the scroll", "water_drop", "blue", 4),
        Habit("move", "Move your body", "Ten minutes counts", "directions_run", "moss", 3),
        Habit("read", "Read a page", "Keep the thread alive", "menu_book", "clay", 7),
        Habit("journal", "Write it down", "A clear mind starts small", "edit_note", "gold", 2),
    )

    val articles = listOf(
        Article(
            "quiet-systems",
            "SYSTEMS",
            "Small systems beat heroic mornings",
            "The best routine is the one that still works on a Tuesday.",
            "A useful ritual is a small promise you can keep when the day is loud. Start with one visible action, give it a home, and let repetition do the convincing.",
            4,
        ),
        Article(
            "deep-work",
            "FOCUS",
            "The room gets quieter when the first task is clear",
            "A gentle plan can protect attention without squeezing the life out of it.",
            "Write the next action in plain language. Put the phone beyond reach. Set a short timer. The point is not to become a machine; it is to make beginning easier.",
            3,
        ),
        Article(
            "money-weather",
            "MONEY",
            "Notice the weather of your spending",
            "A quick note turns an invisible pattern into something you can change.",
            "Spending is information, not a character verdict. A few honest entries can show where the month is asking for attention and where it is already doing fine.",
            5,
        ),
    )

    val manga = listOf(
        Manga("lantern-hollow", "Lantern Hollow", "M. Aster", "Fantasy", 42, "Ongoing", "A quiet town, a bright forest, and one promise left open.", 12, "reading"),
        Manga("tide-tinder", "Tide & Tinder", "N. Vale", "Adventure", 28, "Ongoing", "Two cartographers follow a coastline that changes at night.", 0, "planned"),
        Manga("quiet-rail", "The Quiet Rail", "S. Kato", "Slice of life", 18, "Completed", "Every station has a story if you stay long enough.", 18, "completed"),
        Manga("glass-orchard", "Glass Orchard", "A. Noor", "Mystery", 31, "Ongoing", "A greenhouse keeps growing flowers from an impossible season.", 4, "reading"),
        Manga("ember-parade", "Ember Parade", "R. Sol", "Drama", 24, "Ongoing", "A brass band walks toward the city at the end of summer.", 0, null),
    )
}
