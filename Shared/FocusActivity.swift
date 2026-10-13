import Foundation
import ActivityKit

/// The ActivityKit model for a focus session. It intentionally contains only value types so the app and
/// the widget extension can compile it independently of the app's FocusTimer class.
struct FocusAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var totalSeconds: Int
        var phase: String
        var status: String
    }

    var title: String
}

enum LiveFocusError: LocalizedError {
    case activitiesDisabled

    var errorDescription: String? {
        switch self {
        case .activitiesDisabled:
            return "Live Activities are off. Turn them on in Settings > Dayforge > Live Activities."
        }
    }
}

/// ActivityKit access is kept in one small helper so authorization and request errors never escape into the
/// timer's normal countdown flow.
enum LiveFocus {
    static var isRunning: Bool {
        !Activity<FocusAttributes>.activities.isEmpty
    }

    static func state(_ snapshot: FocusWidgetSnapshot) -> FocusAttributes.ContentState {
        .init(remainingSeconds: snapshot.remainingSeconds,
              totalSeconds: snapshot.totalSeconds,
              phase: snapshot.phase.rawValue,
              status: snapshot.status)
    }

    static func start(_ snapshot: FocusWidgetSnapshot) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveFocusError.activitiesDisabled
        }
        guard !isRunning else { return }

        _ = try Activity.request(
            attributes: FocusAttributes(title: "Focus"),
            content: ActivityContent(state: state(snapshot), staleDate: nil)
        )
    }

    static func update(_ snapshot: FocusWidgetSnapshot) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for activity in Activity<FocusAttributes>.activities {
            await activity.update(ActivityContent(state: state(snapshot), staleDate: nil))
        }
    }

    static func end(_ snapshot: FocusWidgetSnapshot? = nil,
                   dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async {
        for activity in Activity<FocusAttributes>.activities {
            if let snapshot {
                await activity.end(ActivityContent(state: state(snapshot), staleDate: nil),
                                   dismissalPolicy: dismissalPolicy)
            } else {
                await activity.end(nil, dismissalPolicy: dismissalPolicy)
            }
        }
    }
}
