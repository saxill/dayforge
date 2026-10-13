import Foundation

/// The cards on Today that can be switched off.
enum TodaySection: String, CaseIterable, Codable, Identifiable {
    case habits, alarm, spending, brain, news

    var id: String { rawValue }

    var title: String {
        switch self {
        case .habits: return "Habits"
        case .alarm: return "Alarm"
        case .spending: return "Spending"
        case .brain: return "Brain training"
        case .news: return "AI news"
        }
    }

    var icon: String {
        switch self {
        case .habits: return "checkmark.circle.fill"
        case .alarm: return "alarm.fill"
        case .spending: return "creditcard.fill"
        case .brain: return "brain.head.profile"
        case .news: return "newspaper.fill"
        }
    }
}

/// Everything you can customise about the app. Saved on the phone and synced with the account.
struct Profile: Codable, Equatable {
    var name = ""
    var theme: ThemePreset = .moss
    /// Profile photo (a small JPEG), synced with the account.
    var avatarData: Data?
    var hiddenSections: Set<TodaySection> = []

    func shows(_ section: TodaySection) -> Bool { !hiddenSections.contains(section) }
}

struct Account: Codable, Equatable {
    var email: String
    var name: String
}

enum SyncState: Equatable {
    case signedOut
    case idle
    case syncing
    case failed(String)
}
