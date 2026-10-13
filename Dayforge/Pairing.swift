import Foundation

/// One day's aggregate motivation data. It intentionally contains no habit names,
/// habit IDs, or any of the user's private CloudData.
struct DayforgeHistoryEntry: Codable, Equatable, Identifiable {
    var id: String { date }

    var date: String
    var pulse: Int
    var habitsDone: Int
    var habitsTotal: Int
    var focusMinutes: Int
    var focusStreakDays: Int
}

struct PairPayload: Codable, Equatable {
    var id: String
    var status: String
    var code: String?
    var partnerName: String?
    var partnerUserId: String?
    var createdAt: Double
}

struct MotivationSummary: Codable, Equatable {
    var userId: String
    var name: String
    var pulse: Int
    var habitsDone: Int
    var habitsTotal: Int
    var focusMinutes: Int
    var focusStreakDays: Int
    var checkedInDate: String?
    var updatedAt: Double
    var history: [DayforgeHistoryEntry]

    private enum CodingKeys: String, CodingKey {
        case userId, name, pulse, habitsDone, habitsTotal, focusMinutes, focusStreakDays
        case checkedInDate, updatedAt, history
    }

    init(userId: String, name: String, pulse: Int, habitsDone: Int, habitsTotal: Int,
         focusMinutes: Int, focusStreakDays: Int, checkedInDate: String?, updatedAt: Double,
         history: [DayforgeHistoryEntry] = []) {
        self.userId = userId
        self.name = name
        self.pulse = pulse
        self.habitsDone = habitsDone
        self.habitsTotal = habitsTotal
        self.focusMinutes = focusMinutes
        self.focusStreakDays = focusStreakDays
        self.checkedInDate = checkedInDate
        self.updatedAt = updatedAt
        self.history = history
    }

    /// History was added after the first pairing API. Treat an older summary as
    /// having no history so the rest of the response remains usable.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            userId: try values.decode(String.self, forKey: .userId),
            name: try values.decode(String.self, forKey: .name),
            pulse: try values.decode(Int.self, forKey: .pulse),
            habitsDone: try values.decode(Int.self, forKey: .habitsDone),
            habitsTotal: try values.decode(Int.self, forKey: .habitsTotal),
            focusMinutes: try values.decode(Int.self, forKey: .focusMinutes),
            focusStreakDays: try values.decode(Int.self, forKey: .focusStreakDays),
            checkedInDate: try values.decodeIfPresent(String.self, forKey: .checkedInDate),
            updatedAt: try values.decode(Double.self, forKey: .updatedAt),
            history: try values.decodeIfPresent([DayforgeHistoryEntry].self, forKey: .history) ?? []
        )
    }
}

struct LatestNudge: Codable, Equatable {
    var fromName: String
    var message: String
    var createdAt: Double
}

struct PairResponse: Codable {
    var pair: PairPayload?
    var summary: MotivationSummary
    var summaries: [MotivationSummary]
    var latestNudge: LatestNudge?

    private enum CodingKeys: String, CodingKey {
        case pair, summary, summaries, latestNudge
    }

    init(pair: PairPayload?, summary: MotivationSummary, summaries: [MotivationSummary] = [], latestNudge: LatestNudge? = nil) {
        self.pair = pair
        self.summary = summary
        self.summaries = summaries
        self.latestNudge = latestNudge
    }

    /// Invite and join return only `pair` and `summary`; GET /pair also returns
    /// the partner summaries and latest nudge.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pair: try values.decodeIfPresent(PairPayload.self, forKey: .pair),
            summary: try values.decode(MotivationSummary.self, forKey: .summary),
            summaries: try values.decodeIfPresent([MotivationSummary].self, forKey: .summaries) ?? [],
            latestNudge: try values.decodeIfPresent(LatestNudge.self, forKey: .latestNudge)
        )
    }
}

/// Local-only state for the motivation feature. It is separate from CloudData,
/// so pairing history never becomes part of the user's private data backup.
struct PairingLocalState: Codable {
    var history: [DayforgeHistoryEntry]
    var pair: PairPayload?
    var summaries: [MotivationSummary]
    var latestNudge: LatestNudge?

    init(history: [DayforgeHistoryEntry] = [], pair: PairPayload? = nil,
         summaries: [MotivationSummary] = [], latestNudge: LatestNudge? = nil) {
        self.history = history
        self.pair = pair
        self.summaries = summaries
        self.latestNudge = latestNudge
    }
}

enum PairingLocalStore {
    private static let key = "dayforge.pairingState"

    static func load() -> PairingLocalState {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(PairingLocalState.self, from: data) else {
            return PairingLocalState()
        }
        return state
    }

    static func save(_ state: PairingLocalState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum PairingDate {
    static func string(from date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
