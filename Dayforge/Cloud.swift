import Foundation
import Security
import SwiftUI
import Combine

// MARK: Keychain

/// Stores the session token. It never goes in UserDefaults or the synced data.
enum Keychain {
    private static let service = "com.omnirush.dayforge.session"

    static func set(_ value: String?, for key: String = "token") {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var item = base
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    static func get(_ key: String = "token") -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: Client

struct CloudError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

/// Talks to Dayforge's bundled sync service. The service address is an app constant rather than a user setting.
enum CloudClient {
    /// The deployed sync service. Keep this out of the app's visible settings UI.
    private static let syncURL = "https://dayforge-sync.sahilchanna344.workers.dev"

    struct AuthResponse: Decodable {
        struct User: Decodable { var email: String; var name: String }
        var token: String
        var user: User
    }

    struct RemoteData: Decodable {
        var data: CloudData?
        var updatedAt: Double
    }

    private struct MotivationPayload: Encodable {
        var pulse: Int
        var habitsDone: Int
        var habitsTotal: Int
        var focusMinutes: Int
        var focusStreakDays: Int
        var checkedInDate: String?
        var history: [DayforgeHistoryEntry]
    }

    private static func send(_ method: String, _ path: String, body: Data? = nil, token: String? = nil) async throws -> Data {
        guard var components = URLComponents(string: syncURL), components.host != nil, components.scheme == "https" else {
            throw CloudError(message: "Dayforge sync is not configured correctly.")
        }
        components.path = path
        guard let url = components.url else { throw CloudError(message: "Dayforge sync is unavailable.") }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.httpBody = body
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "content-type") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) } catch {
            throw CloudError(message: "Couldn't reach Dayforge sync. Check your connection and try again.")
        }
        guard let http = response as? HTTPURLResponse else { throw CloudError(message: "Unexpected reply from the server.") }
        if !(200..<300).contains(http.statusCode) {
            let text = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw CloudError(message: text ?? "The server said no (\(http.statusCode)).")
        }
        return data
    }

    static func register(email: String, password: String, name: String) async throws -> AuthResponse {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password, "name": name])
        return try JSONDecoder().decode(AuthResponse.self, from: try await send("POST", "/auth/register", body: body))
    }

    static func login(email: String, password: String) async throws -> AuthResponse {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        return try JSONDecoder().decode(AuthResponse.self, from: try await send("POST", "/auth/login", body: body))
    }

    static func logout(token: String) async { _ = try? await send("POST", "/auth/logout", token: token) }

    static func pull(token: String) async throws -> RemoteData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RemoteData.self, from: try await send("GET", "/data", token: token))
    }

    static func push(_ data: CloudData, token: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try JSONSerialization.data(withJSONObject: ["data": try JSONSerialization.jsonObject(with: encoder.encode(data))])
        _ = try await send("PUT", "/data", body: payload, token: token)
    }

    static func deleteAccount(email: String, token: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email])
        _ = try await send("DELETE", "/account", body: body, token: token)
    }

    static func invitePair(token: String) async throws -> PairResponse {
        let data = try await send("POST", "/pair/invite", token: token)
        return try JSONDecoder().decode(PairResponse.self, from: data)
    }

    static func joinPair(code: String, token: String) async throws -> PairResponse {
        let body = try JSONSerialization.data(withJSONObject: ["code": code])
        let data = try await send("POST", "/pair/join", body: body, token: token)
        return try JSONDecoder().decode(PairResponse.self, from: data)
    }

    static func getPair(token: String) async throws -> PairResponse {
        let data = try await send("GET", "/pair", token: token)
        return try JSONDecoder().decode(PairResponse.self, from: data)
    }

    static func updateMotivation(_ summary: MotivationSummary, token: String) async throws {
        let body = try JSONEncoder().encode(MotivationPayload(
            pulse: summary.pulse,
            habitsDone: summary.habitsDone,
            habitsTotal: summary.habitsTotal,
            focusMinutes: summary.focusMinutes,
            focusStreakDays: summary.focusStreakDays,
            checkedInDate: summary.checkedInDate,
            history: summary.history
        ))
        _ = try await send("PUT", "/pair/motivation", body: body, token: token)
    }

    static func sendNudge(message: String, token: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["message": message])
        _ = try await send("POST", "/pair/nudge", body: body, token: token)
    }

    static func leavePair(token: String) async throws {
        _ = try await send("POST", "/pair/leave", token: token)
    }
}

// MARK: What gets saved and synced

/// The app's own data (not the manga covers or your PDF files, which stay on the phone).
struct CloudData: Codable, Equatable {
    var profile: Profile
    var habits: [Habit]
    var alarm: Alarm
    var expenses: [Expense]
    var drillBests: [String: Int]
    var drillRounds: Int
    var focusSessionsToday: Int
    var focusMinutesToday: Int
    var focusStreakDays: Int
    var library: [String: String]
    var lastRead: [String: Double]
    var sourceLinks: [String: String]
    var savedAt: Date
}

extension AppState {
    private var stateFile: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("Dayforge", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func makeCloudData(savedAt: Date = Date()) -> CloudData {
        CloudData(profile: profile, habits: habits, alarm: alarm, expenses: expenses,
                  drillBests: drillBests, drillRounds: drillRounds,
                  focusSessionsToday: focusSessionsToday, focusMinutesToday: focusMinutesToday,
                  focusStreakDays: focusStreakDays,
                  library: library.mapValues(\.rawValue), lastRead: lastRead, sourceLinks: sourceLinks,
                  savedAt: savedAt)
    }

    /// Replaces the local data with a snapshot (from the cloud or from disk).
    func apply(_ data: CloudData) {
        applyingRemote = true
        profile = data.profile
        habits = data.habits
        alarm = data.alarm
        persistHabits()
        persistAlarm()
        expenses = data.expenses
        drillBests = data.drillBests
        drillRounds = data.drillRounds
        focusSessionsToday = data.focusSessionsToday
        focusMinutesToday = data.focusMinutesToday
        focusStreakDays = data.focusStreakDays
        library = data.library.compactMapValues { LibraryStatus(rawValue: $0) }
        lastRead = data.lastRead
        sourceLinks = data.sourceLinks
        saveLibrary()
        publishWidgetData()
        DispatchQueue.main.async { self.applyingRemote = false }
    }

    /// A fingerprint that ignores the timestamp, to tell real changes from noise.
    private func fingerprint(_ data: CloudData) -> Int {
        var copy = data
        copy.savedAt = .distantPast
        return (try? Self.encoder.encode(copy))?.hashValue ?? 0
    }

    // MARK: Lifecycle

    /// Loads the saved profile and data, restores the session and starts watching for changes.
    func startCloud() {
        if let url = stateFile, let raw = try? Data(contentsOf: url), let saved = try? Self.decoder.decode(CloudData.self, from: raw) {
            apply(saved)
        }
        Theme.preset = profile.theme
        if let email = UserDefaults.standard.string(forKey: "dayforge.accountEmail"), Keychain.get() != nil {
            account = Account(email: email, name: UserDefaults.standard.string(forKey: "dayforge.accountName") ?? "")
            syncState = .idle
            Task { await pullAndMerge() }
        }
        lastPushedHash = fingerprint(makeCloudData())
        changeSink = objectWillChange
            .debounce(for: .seconds(2.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.changed() }
    }

    private func changed() {
        guard !applyingRemote else { return }
        let snapshot = makeCloudData()
        let print = fingerprint(snapshot)
        guard print != lastPushedHash else { return }
        lastPushedHash = print
        if let url = stateFile, let raw = try? Self.encoder.encode(snapshot) { try? raw.write(to: url, options: .atomic) }
        guard account != nil else { return }
        syncTask?.cancel()
        syncTask = Task { await push(snapshot) }
    }

    // MARK: Account

    func signIn(email: String, password: String) async throws {
        let response = try await CloudClient.login(email: email, password: password)
        await finishSignIn(response)
    }

    func register(email: String, password: String, name: String) async throws {
        let response = try await CloudClient.register(email: email, password: password, name: name)
        await finishSignIn(response, preferLocal: true)
    }

    @MainActor
    private func finishSignIn(_ response: CloudClient.AuthResponse, preferLocal: Bool = false) async {
        Keychain.set(response.token)
        UserDefaults.standard.set(response.user.email, forKey: "dayforge.accountEmail")
        UserDefaults.standard.set(response.user.name, forKey: "dayforge.accountName")
        account = Account(email: response.user.email, name: response.user.name)
        if profile.name.isEmpty { profile.name = response.user.name }
        syncState = .idle
        // Signing in on a fresh install brings the cloud copy down; a brand-new account uploads this phone's data.
        if preferLocal { await push(makeCloudData()) } else { await pullAndMerge(preferRemote: true) }
        await refreshPair()
        await publishMotivation()
    }

    @MainActor
    func signOut() async {
        if let token = Keychain.get() { await CloudClient.logout(token: token) }
        Keychain.set(nil)
        UserDefaults.standard.removeObject(forKey: "dayforge.accountEmail")
        UserDefaults.standard.removeObject(forKey: "dayforge.accountName")
        account = nil
        syncState = .signedOut
        lastSynced = nil
        clearPairState()
    }

    @MainActor
    func deleteAccount() async throws {
        guard let token = Keychain.get(), let email = account?.email else { return }
        try await CloudClient.deleteAccount(email: email, token: token)
        await signOut()
    }

    // MARK: Sync

    @MainActor
    func pullAndMerge(preferRemote: Bool = false) async {
        guard let token = Keychain.get() else { return }
        syncState = .syncing
        do {
            let remote = try await CloudClient.pull(token: token)
            if let data = remote.data {
                let localTime = (try? FileManager.default.attributesOfItem(atPath: stateFile?.path ?? "")[.modificationDate] as? Date) ?? .distantPast
                if preferRemote || data.savedAt > localTime {
                    apply(data)
                    lastPushedHash = fingerprint(data)
                    if let url = stateFile, let raw = try? Self.encoder.encode(data) { try? raw.write(to: url, options: .atomic) }
                } else {
                    await push(makeCloudData())
                    return
                }
            } else {
                await push(makeCloudData())
                return
            }
            lastSynced = Date()
            syncState = .idle
        } catch {
            handleSyncError(error)
        }
    }

    @MainActor
    func push(_ snapshot: CloudData) async {
        guard let token = Keychain.get() else { return }
        syncState = .syncing
        do {
            try await CloudClient.push(snapshot, token: token)
            lastSynced = Date()
            syncState = .idle
        } catch {
            handleSyncError(error)
        }
    }

    @MainActor
    private func handleSyncError(_ error: Error) {
        let message = error.localizedDescription
        if message.contains("session expired") || message.contains("Please sign in") {
            Keychain.set(nil)
            account = nil
            syncState = .failed("Your session expired. Sign in again.")
        } else {
            syncState = .failed(message)
        }
    }
}
