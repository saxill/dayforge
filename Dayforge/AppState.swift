import SwiftUI
import WidgetKit

@MainActor
final class AppState: ObservableObject {
    @Published var habits: [Habit]
    @Published var alarm: Alarm
    @Published var expenses: [Expense] = [] {
        didSet { publishFinance() }
    }
    /// Set when the widget's Add button opens the app; Today shows the expense sheet.
    @Published var requestAddExpense = false
    /// The manga library: which series are followed, and how far each one has been read.
    @Published var library: [String: LibraryStatus] = [:]
    @Published var lastRead: [String: Double] = [:]
    /// Every series in the app: the ones from the MangaPin backup plus any started from your own files.
    @Published var importedManga: [Manga] = []
    /// PDF / CBZ files you attached to a series, by series id. The files live in Application Support.
    @Published var localFiles: [String: [LocalChapter]] = [:]
    /// The last page you had open for each series on its source site (its manga page or a chapter).
    @Published var sourceLinks: [String: String] = [:]

    /// Best score (problems solved) per drill: "sprint-3", "marathon-4", "daily".
    @Published var drillBests: [String: Int] = [:]
    @Published var drillRounds = 0

    @Published var focusSessionsToday = 0
    @Published var focusMinutesToday = 0
    @Published var focusStreakDays = 0
    @Published private(set) var focusLiveActivityVisible = false
    @Published private(set) var focusLiveActivityError: String?

    /// Name, theme, blob look and which Today cards show. Synced with the account.
    @Published var profile = Profile() {
        didSet { Theme.preset = profile.theme }
    }
    /// The signed-in account, if any. The token itself lives in the Keychain.
    @Published var account: Account?
    @Published var syncState: SyncState = .signedOut
    @Published var lastSynced: Date?
    @Published var pair: PairPayload?
    @Published var pairSummaries: [MotivationSummary] = []
    @Published var latestNudge: LatestNudge?
    /// Aggregate-only daily snapshots kept separately from private CloudData.
    @Published private(set) var motivationHistory: [DayforgeHistoryEntry] = []
    @Published var pairLoading = false
    @Published var pairError: String?
    var applyingRemote = false
    var lastPushedHash = 0
    var syncTask: Task<Void, Never>?
    var changeSink: Any?
    private var focusActivityTask: Task<Void, Never>?
    private var motivationTask: Task<Void, Never>?
    private var focusLiveActivitySuppressed = false

    @Published var focusDurationMinutes: Int
    @Published var monthlyBudget: Double
    let focus: FocusTimer
    let articles = SampleData.articles

    init() {
        let savedDuration = DayforgeLocalStore.focusDurationMinutes
        let savedBudget = DayforgeLocalStore.monthlyBudget
        habits = DayforgeLocalStore.loadHabits() ?? SampleData.habits
        alarm = DayforgeLocalStore.loadAlarm() ?? SampleData.alarm
        focusDurationMinutes = savedDuration
        monthlyBudget = savedBudget
        focus = FocusTimer(minutes: savedDuration)
        focus.onStart = { [weak self] in
            self?.focusLiveActivitySuppressed = false
            self?.focusLiveActivityError = nil
        }
        focus.onStateChange = { [weak self] in self?.focusStateDidChange() }
        focus.onComplete = { [weak self] in self?.recordFocusSession() }
        if !loadLibrary() { seedFromBundledBackup() }
        startCloud()
        restorePairingState()
        clearRetiredDemoData()
        recordMotivationSnapshot()
        drainPending()
        publishFinance()
        publishWidgetData()
        Task { [weak self] in
            guard let self else { return }
            await self.refreshPair()
            await self.publishMotivation()
        }
    }

    /// Earlier builds started with invented expenses, streaks and focus stats. Remove them once.
    private func clearRetiredDemoData() {
        guard !UserDefaults.standard.bool(forKey: "dayforge.demoCleared") else { return }
        UserDefaults.standard.set(true, forKey: "dayforge.demoCleared")
        let originalHabits = habits
        expenses.removeAll { item in
            SampleData.retiredDemoExpenses.contains { $0.amount == item.amount && $0.note == item.note }
        }
        let demoStreaks = ["water": 12, "walk": 5, "read": 8, "journal": 3]
        for index in habits.indices where demoStreaks[habits[index].id] == habits[index].streak {
            habits[index].streak = 0
            habits[index].isDone = false
        }
        if focusSessionsToday == 2 && focusMinutesToday == 50 && focusStreakDays == 4 {
            focusSessionsToday = 0; focusMinutesToday = 0; focusStreakDays = 0
        }
        if habits != originalHabits { persistHabits() }
    }

    // MARK: Habits

    var habitsDone: Int { habits.filter(\.isDone).count }

    var habitProgress: Double {
        habits.isEmpty ? 0 : Double(habitsDone) / Double(habits.count)
    }

    func toggleHabit(_ id: String) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].isDone.toggle()
        persistHabits()
        publishWidgetData()
        queueMotivationPublish()
    }

    func updateHabits(_ updated: [Habit]) {
        let cleaned = updated.map { habit in
            var habit = habit
            habit.title = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
            habit.detail = habit.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return habit
        }
        guard cleaned.allSatisfy({ !$0.title.isEmpty }) else { return }
        habits = cleaned
        persistHabits()
        publishWidgetData()
        queueMotivationPublish()
    }

    // MARK: Alarm

    func setAlarm(_ isOn: Bool) {
        alarm.isOn = isOn
        persistAlarm()
        publishWidgetData()
    }

    func updateAlarm(_ updated: Alarm) {
        alarm = updated
        persistAlarm()
        publishWidgetData()
    }

    // MARK: Money

    var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    private var currentMonthExpenses: [Expense] {
        let calendar = Calendar.current
        return expenses.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    var monthlySpend: Double { currentMonthExpenses.reduce(0) { $0 + $1.amount } }

    var budgetProgress: Double { monthlyBudget > 0 ? min(1, monthlySpend / monthlyBudget) : 0 }

    var recentExpenses: [Expense] {
        Array(expenses.sorted { $0.date > $1.date }.prefix(3))
    }

    // MARK: Shortcuts and widget

    /// Writes this month's totals where the spending widget and intents can read them.
    func publishFinance() {
        let calendar = Calendar.current
        let today = expenses.filter { calendar.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
        let snapshot = FinanceSnapshot(monthKey: FinanceStore.monthKey(), monthSpend: monthlySpend, todaySpend: today,
                                       budget: monthlyBudget, currencyCode: currencyCode)
        guard snapshot != FinanceStore.snapshot else { return }
        FinanceStore.snapshot = snapshot
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Folds in expenses logged by Shortcuts or the widget while the app was closed.
    func drainPending() {
        let queued = FinanceStore.takePending()
        let known = Set(expenses.map { $0.id.uuidString })
        for item in queued where !known.contains(item.id) {
            expenses.append(Expense(id: UUID(uuidString: item.id) ?? UUID(), amount: item.amount,
                                    category: ExpenseCategory(rawValue: item.category) ?? .other, note: item.note, date: item.date))
        }
        if FinanceStore.openAddRequested {
            FinanceStore.openAddRequested = false
            requestAddExpense = true
        }
    }

    func addExpense(amount: Double, category: ExpenseCategory, note: String) {
        let cleaned = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let rounded = (amount * 100).rounded() / 100
        expenses.append(Expense(amount: rounded, category: category, note: cleaned))
    }

    @discardableResult
    func setMonthlyBudget(_ value: Double) -> Bool {
        guard value.isFinite, value > 0, value <= 1_000_000 else { return false }
        let rounded = (value * 100).rounded() / 100
        monthlyBudget = rounded
        DayforgeLocalStore.saveMonthlyBudget(rounded)
        publishFinance()
        return true
    }

    // MARK: Focus

    @discardableResult
    func setFocusDuration(minutes: Int) -> Bool {
        guard focus.setDuration(minutes: minutes) else { return false }
        focusDurationMinutes = minutes
        DayforgeLocalStore.saveFocusDuration(minutes: minutes)
        return true
    }

    private var focusWidgetSnapshot: FocusWidgetSnapshot {
        let phase: FocusWidgetPhase
        switch focus.phase {
        case .idle: phase = .idle
        case .running: phase = .running
        case .paused: phase = .paused
        case .finished: phase = .finished
        }
        return FocusWidgetSnapshot(remainingSeconds: focus.remaining,
                                   totalSeconds: focus.totalSeconds,
                                   phase: phase,
                                   status: focus.statusText)
    }

    private func publishFocusWidget() {
        FocusWidgetStore.snapshot = focusWidgetSnapshot
        WidgetCenter.shared.reloadTimelines(ofKind: "DayforgeFocus")
    }

    /// Publishes the small, process-safe snapshots used by the extra widgets.
    func publishWidgetData() {
        let habitItems = habits.map {
            HabitWidgetItem(id: $0.id, title: $0.title, detail: $0.detail, icon: $0.icon,
                            accent: $0.accent.rawValue, streak: $0.streak, isDone: $0.isDone)
        }
        HabitsWidgetStore.snapshot = HabitsWidgetSnapshot(completed: habitsDone,
                                                          total: habits.count,
                                                          items: habitItems)
        AlarmWidgetStore.snapshot = AlarmWidgetSnapshot(hour: alarm.hour, minute: alarm.minute,
                                                        label: alarm.label, repeatText: alarm.repeatText,
                                                        isOn: alarm.isOn)
        if let article = articles.first {
            AIBriefWidgetStore.snapshot = AIBriefWidgetSnapshot(tag: article.tag, title: article.title,
                                                                 summary: article.summary, minutes: article.minutes,
                                                                 icon: article.icon)
        }
        publishFocusWidget()
        WidgetCenter.shared.reloadTimelines(ofKind: "DayforgeHabits")
        WidgetCenter.shared.reloadTimelines(ofKind: "DayforgeAlarm")
        WidgetCenter.shared.reloadTimelines(ofKind: "DayforgeAIBrief")
    }

    private func focusStateDidChange() {
        publishFocusWidget()
        focusActivityTask?.cancel()
        let snapshot = focusWidgetSnapshot

        switch focus.phase {
        case .idle:
            focusLiveActivitySuppressed = false
            focusLiveActivityVisible = false
            focusActivityTask = Task { await LiveFocus.end() }

        case .running:
            guard !focusLiveActivitySuppressed else { return }
            let previousTask = focusActivityTask
            focusActivityTask = Task { [weak self] in
                await previousTask?.value
                guard let self, self.focus.phase == .running, !self.focusLiveActivitySuppressed else { return }
                if LiveFocus.isRunning {
                    self.focusLiveActivityVisible = true
                    await LiveFocus.update(snapshot)
                } else {
                    do {
                        try LiveFocus.start(snapshot)
                        self.focusLiveActivityVisible = LiveFocus.isRunning
                    } catch {
                        self.focusLiveActivitySuppressed = true
                        self.focusLiveActivityError = error.localizedDescription
                    }
                }
            }

        case .paused:
            guard !focusLiveActivitySuppressed, LiveFocus.isRunning else { return }
            focusLiveActivityVisible = true
            focusActivityTask = Task { await LiveFocus.update(snapshot) }

        case .finished:
            guard !focusLiveActivitySuppressed, LiveFocus.isRunning else { return }
            focusLiveActivityVisible = true
            focusActivityTask = Task { [weak self] in
                await LiveFocus.update(snapshot)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, let self, self.focus.phase == .finished else { return }
                await LiveFocus.end(snapshot)
                self.focusLiveActivityVisible = false
            }
        }
    }

    func showFocusLiveActivity() {
        guard focus.phase != .idle else { return }
        focusLiveActivitySuppressed = false
        focusLiveActivityError = nil
        do {
            try LiveFocus.start(focusWidgetSnapshot)
            focusLiveActivityVisible = LiveFocus.isRunning
            if focusLiveActivityVisible {
                Task { await LiveFocus.update(focusWidgetSnapshot) }
            }
        } catch {
            focusLiveActivitySuppressed = true
            focusLiveActivityError = error.localizedDescription
        }
    }

    func stopFocusLiveActivity() {
        focusLiveActivitySuppressed = true
        focusLiveActivityVisible = false
        focusActivityTask?.cancel()
        focusActivityTask = Task { await LiveFocus.end() }
    }

    private func recordFocusSession() {
        focusSessionsToday += 1
        focusMinutesToday += focus.totalSeconds / 60
        if focusSessionsToday == 1 { focusStreakDays += 1 }
        queueMotivationPublish()
    }

    // MARK: Drills

    private func drillKey(_ mode: DrillMode, level: Int) -> String {
        mode == .daily ? "daily" : "\(mode.rawValue)-\(level)"
    }

    func bestScore(_ mode: DrillMode, level: Int) -> Int? {
        drillBests[drillKey(mode, level: level)]
    }

    /// Stores the round and marks it as a personal best when it beats the old one.
    func record(_ result: DrillResult) -> DrillResult {
        var scored = result
        drillRounds += 1
        let key = drillKey(result.mode, level: result.level)
        let previous = drillBests[key]
        if result.correct > (previous ?? 0) {
            drillBests[key] = result.correct
            scored.isPersonalBest = true
        }
        return scored
    }

    // MARK: Pulse

    /// A simple 0 to 100 score from habits, focus and the alarm.
    var pulse: Int {
        let habits = habitProgress * 55
        let focusPart = min(1, Double(focusMinutesToday) / 100) * 35
        let alarmPart = alarm.isOn ? 10.0 : 0
        return Int((habits + focusPart + alarmPart).rounded())
    }

    /// The score shared with a motivation partner. It deliberately uses only habits and focus,
    /// leaving private alarm settings out of the shared summary.
    var motivationPulse: Int {
        let habits = habitProgress * 65
        let focusPart = min(1, Double(focusMinutesToday) / 100) * 35
        return Int((habits + focusPart).rounded())
    }

    var localMotivationSummary: MotivationSummary {
        MotivationSummary(
            userId: "local",
            name: profile.name.isEmpty ? (account?.name ?? "You") : profile.name,
            pulse: motivationPulse,
            habitsDone: habitsDone,
            habitsTotal: habits.count,
            focusMinutes: focusMinutesToday,
            focusStreakDays: focusStreakDays,
            checkedInDate: motivationDate,
            updatedAt: Date().timeIntervalSince1970,
            history: motivationHistory
        )
    }

    private var motivationDate: String { PairingDate.string() }

    /// Records only the current day's aggregate status and retains the newest
    /// 30 dates. The entry is useful even while signed out or offline.
    @discardableResult
    func recordMotivationSnapshot() -> DayforgeHistoryEntry {
        let entry = DayforgeHistoryEntry(
            date: motivationDate,
            pulse: motivationPulse,
            habitsDone: habitsDone,
            habitsTotal: habits.count,
            focusMinutes: focusMinutesToday,
            focusStreakDays: focusStreakDays
        )
        var byDate = Dictionary(uniqueKeysWithValues: motivationHistory.map { ($0.date, $0) })
        byDate[entry.date] = entry
        motivationHistory = byDate.values.sorted { $0.date > $1.date }.prefix(30).map { $0 }
        persistPairingState()
        return entry
    }

    // MARK: Motivation partner

    func refreshPair() async {
        guard account != nil, let token = Keychain.get() else {
            clearPairState()
            return
        }

        pairLoading = true
        pairError = nil
        defer { pairLoading = false }

        do {
            let response = try await CloudClient.getPair(token: token)
            applyPairResponse(response)
        } catch {
            if !Task.isCancelled { pairError = error.localizedDescription }
        }
    }

    func createPairInvite() async {
        guard account != nil, let token = Keychain.get() else {
            clearPairState()
            return
        }

        pairLoading = true
        pairError = nil
        defer { pairLoading = false }

        do {
            let response = try await CloudClient.invitePair(token: token)
            applyPairResponse(response)
            await publishMotivation()
        } catch {
            if !Task.isCancelled { pairError = error.localizedDescription }
        }
    }

    func joinPair(code: String) async {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard isValidPairCode(normalized) else {
            pairError = "Enter the 6-character team code."
            return
        }
        guard account != nil, let token = Keychain.get() else {
            clearPairState()
            return
        }

        pairLoading = true
        pairError = nil
        defer { pairLoading = false }

        do {
            let response = try await CloudClient.joinPair(code: normalized, token: token)
            applyPairResponse(response)
            await publishMotivation()
        } catch {
            if !Task.isCancelled { pairError = error.localizedDescription }
        }
    }

    func sendPairNudge(message: String) async {
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            pairError = "Write a short message first."
            return
        }
        guard cleaned.count <= 120 else {
            pairError = "Keep your encouragement under 120 characters."
            return
        }
        guard account != nil, let token = Keychain.get(), pair != nil else {
            pairError = "Join a team before sending encouragement."
            return
        }

        pairLoading = true
        pairError = nil
        defer { pairLoading = false }

        do {
            try await CloudClient.sendNudge(message: cleaned, token: token)
            latestNudge = LatestNudge(
                fromName: localMotivationSummary.name,
                message: cleaned,
                createdAt: Date().timeIntervalSince1970
            )
            persistPairingState()
        } catch {
            if !Task.isCancelled { pairError = error.localizedDescription }
        }
    }

    func leavePair() async {
        guard let token = Keychain.get(), pair != nil else {
            clearPairState()
            return
        }

        pairLoading = true
        pairError = nil
        defer { pairLoading = false }

        do {
            try await CloudClient.leavePair(token: token)
            clearPairState()
        } catch {
            if !Task.isCancelled { pairError = error.localizedDescription }
        }
    }

    /// Sends only motivation metrics; private finance, alarm, manga and note data stay local.
    func publishMotivation() async {
        recordMotivationSnapshot()
        guard account != nil, let token = Keychain.get(), pair != nil else { return }
        let summary = localMotivationSummary
        do {
            try await CloudClient.updateMotivation(summary, token: token)
            pairError = nil
        } catch {
            // Motivation sync is best-effort and never interrupts local use, but
            // the UI should make an unavailable connection understandable.
            if !Task.isCancelled { pairError = error.localizedDescription }
        }
    }

    private func queueMotivationPublish() {
        recordMotivationSnapshot()
        guard account != nil, pair != nil else { return }
        motivationTask?.cancel()
        motivationTask = Task { [weak self] in
            guard let self else { return }
            await self.publishMotivation()
        }
    }

    private func applyPairResponse(_ response: PairResponse) {
        pair = response.pair
        guard response.pair != nil else {
            pairSummaries = []
            latestNudge = nil
            persistPairingState()
            return
        }

        var ownSummary = response.summary
        if ownSummary.history.isEmpty, !motivationHistory.isEmpty {
            ownSummary.history = motivationHistory
        }
        var summaries = response.summaries
        if let index = summaries.firstIndex(where: { $0.userId == ownSummary.userId }) {
            summaries[index] = ownSummary
        } else {
            summaries.insert(ownSummary, at: 0)
        }
        pairSummaries = summaries
        latestNudge = response.latestNudge
        persistPairingState()
    }

    func clearPairState() {
        pair = nil
        pairSummaries = []
        latestNudge = nil
        pairLoading = false
        pairError = nil
        persistPairingState()
    }

    private func restorePairingState() {
        let saved = PairingLocalStore.load()
        motivationHistory = saved.history
        guard account != nil else { return }
        pair = saved.pair
        pairSummaries = saved.summaries
        latestNudge = saved.latestNudge
    }

    private func persistPairingState() {
        PairingLocalStore.save(PairingLocalState(
            history: motivationHistory,
            pair: pair,
            summaries: pairSummaries,
            latestNudge: latestNudge
        ))
    }

    private func isValidPairCode(_ code: String) -> Bool {
        guard code.count == 6 else { return false }
        return code.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) ||
            (65...90).contains(scalar.value)
        }
    }

    // MARK: Manga library

    var allManga: [Manga] { importedManga }

    func isSaved(_ manga: Manga) -> Bool { library[manga.id] != nil }

    func status(of manga: Manga) -> LibraryStatus? { library[manga.id] }

    func chaptersRead(_ manga: Manga) -> Double { lastRead[manga.id] ?? 0 }

    /// Whole chapters waiting in the library (zero for series that are not followed).
    func unread(_ manga: Manga) -> Int {
        guard library[manga.id] != nil else { return 0 }
        return max(0, Int((manga.chapters - chaptersRead(manga) + 0.0001).rounded(.down)))
    }

    func readProgress(_ manga: Manga) -> Double {
        manga.chapters <= 0 ? 0 : min(1, chaptersRead(manga) / manga.chapters)
    }

    func nextChapter(_ manga: Manga) -> Double {
        min(manga.chapters, chaptersRead(manga).rounded(.down) + 1)
    }

    /// Pass nil to remove the series from the library.
    func setStatus(_ manga: Manga, _ status: LibraryStatus?) {
        if let status {
            library[manga.id] = status
        } else {
            library.removeValue(forKey: manga.id)
            lastRead.removeValue(forKey: manga.id)
        }
        saveLibrary()
    }

    func toggleReadingList(_ manga: Manga) {
        setStatus(manga, isSaved(manga) ? nil : .planned)
    }

    func markRead(_ manga: Manga, chapter: Double) {
        lastRead[manga.id] = max(chaptersRead(manga), chapter)
        if library[manga.id] == nil || library[manga.id] == .planned { library[manga.id] = .reading }
        if chaptersRead(manga) >= manga.chapters && manga.status == "Completed" { library[manga.id] = .completed }
        saveLibrary()
    }

    /// Sets progress exactly, up or down (used by the stepper on imported series).
    func setProgress(_ manga: Manga, to chapter: Double) {
        lastRead[manga.id] = min(max(0, chapter), manga.chapters)
        if library[manga.id] == nil { library[manga.id] = .reading }
        if library[manga.id] == .planned && chaptersRead(manga) > 0 { library[manga.id] = .reading }
        saveLibrary()
    }

    func markAllUpdatesRead() {
        for manga in libraryManga where library[manga.id] == .reading {
            lastRead[manga.id] = manga.chapters
        }
        saveLibrary()
    }

    var libraryManga: [Manga] { allManga.filter { library[$0.id] != nil } }

    func libraryManga(filter: LibraryStatus?) -> [Manga] {
        guard let filter else { return libraryManga }
        return libraryManga.filter { library[$0.id] == filter }
    }

    var continueReading: [Manga] {
        libraryManga.filter { library[$0.id] == .reading && unread($0) > 0 }
    }

    /// The newest chapter of every followed series that still has unread chapters, newest first.
    var updates: [ChapterUpdate] {
        let now = Date()
        return continueReading.enumerated().map { offset, manga in
            let hours = manga.latestAt.map { max(1, Int(now.timeIntervalSince($0) / 3600)) } ?? (2 + (offset * 7 + manga.title.count) % 30)
            return ChapterUpdate(mangaID: manga.id, chapter: manga.chapters,
                                 title: manga.chapterTitles.first ?? "New chapter",
                                 hoursAgo: hours, date: manga.latestAt)
        }
        .sorted { $0.hoursAgo < $1.hoursAgo }
    }

    func mangaByID(_ id: String) -> Manga? { allManga.first { $0.id == id } }

    // MARK: Backup import

    /// Adds the series from a parsed backup. `statusForFolder` maps each backup folder to a library status.
    /// Returns how many series were added or updated.
    @discardableResult
    func importBackup(_ items: [BackupItem], statusForFolder: [Int: LibraryStatus]) -> Int {
        for item in items {
            let id = "mp-\(item.id)"
            let status = statusForFolder[item.folder] ?? .planned
            let entry = Manga(id: id, title: item.name, author: item.sourceName, genre: "Tracked series",
                              chapters: item.latest, status: status == .completed ? "Completed" : "Ongoing",
                              blurb: "From your MangaPin backup. Added \(item.addedText).",
                              chapterTitles: [], art: .paperMoon, coverData: item.coverData,
                              source: item.sourceName, addedAt: item.addedAt, latestAt: item.latestAt,
                              pageURL: item.pageURL)
            if let index = importedManga.firstIndex(where: { $0.id == id }) {
                importedManga[index] = entry
            } else {
                importedManga.append(entry)
            }
            library[id] = status
            let progress = item.progress ?? 0
            lastRead[id] = status == .completed ? max(progress, item.latest) : min(progress, item.latest)
        }
        saveLibrary()
        return items.count
    }

    /// First launch: load the backup that ships inside the app, with folders mapped by their best guess.
    private func seedFromBundledBackup() {
        guard let url = bundledMangaBackupURL(),
              let data = try? Data(contentsOf: url),
              let backup = try? BackupParser.parse(data, fileName: "MangaPin backup") else { return }
        var mapping: [Int: LibraryStatus] = [:]
        for folder in backup.folders { mapping[folder] = backup.suggestedStatus(forFolder: folder) }
        importBackup(backup.items, statusForFolder: mapping)
    }

    /// Libraries saved before page links existed: fill them in from the backup bundled with the app.
    private func backfillPageURLs() {
        guard importedManga.contains(where: { $0.id.hasPrefix("mp-") && ($0.pageURL == nil || $0.pageURL?.contains("mangafire.to/manga/") == true) }),
              let url = bundledMangaBackupURL(),
              let data = try? Data(contentsOf: url),
              let backup = try? BackupParser.parse(data, fileName: "MangaPin backup") else { return }
        let links = Dictionary(backup.items.compactMap { item in item.pageURL.map { ("mp-\(item.id)", $0) } },
                               uniquingKeysWith: { first, _ in first })
        var changed = false
        for index in importedManga.indices where importedManga[index].pageURL == nil || importedManga[index].pageURL?.contains("mangafire.to/manga/") == true {
            if let link = links[importedManga[index].id] { importedManga[index].pageURL = link; changed = true }
        }
        if changed { saveLibrary() }
    }

    /// The original private backup is preferred on a developer's machine. Public
    /// builds use the small synthetic fixture so a clean checkout still has a
    /// useful Manga Shelf without publishing personal reading history.
    private func bundledMangaBackupURL() -> URL? {
        Bundle.main.url(forResource: "MangaPin", withExtension: "json")
            ?? Bundle.main.url(forResource: "MangaPinPublic", withExtension: "json")
    }

    func saveSourceLink(_ url: URL, for id: String) {
        guard sourceLinks[id] != url.absoluteString else { return }
        sourceLinks[id] = url.absoluteString
        saveLibrary()
    }

    func sourceLink(for id: String) -> URL? { sourceLinks[id].flatMap(URL.init(string:)) }

    // MARK: Your own files

    private var filesDirectory: URL? {
        guard let dir = libraryFile?.deletingLastPathComponent().appendingPathComponent("Files", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func url(for file: LocalChapter) -> URL? { filesDirectory?.appendingPathComponent(file.stored) }

    /// Copies a PDF or CBZ into the app. With no series given, the file starts a new one named after it.
    @discardableResult
    func addLocalFile(from source: URL, to manga: Manga?) -> Manga? {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        guard let dir = filesDirectory else { return nil }
        let ext = source.pathExtension.lowercased()
        let stored = "\(UUID().uuidString).\(ext)"
        do { try FileManager.default.copyItem(at: source, to: dir.appendingPathComponent(stored)) } catch { return nil }
        let name = source.deletingPathExtension().lastPathComponent
        let file = LocalChapter(id: UUID().uuidString, name: name, stored: stored)

        var target = manga
        if target == nil {
            let entry = Manga(id: "own-\(UUID().uuidString)", title: name, author: "My files", genre: "Own file",
                              chapters: 0, status: "Ongoing", blurb: "Series made from files you added.",
                              chapterTitles: [], art: .paperMoon, source: "My files", addedAt: Date(), latestAt: Date())
            importedManga.append(entry)
            library[entry.id] = .reading
            target = entry
        }
        guard let series = target else { return nil }
        localFiles[series.id, default: []].append(file)
        if series.source == "My files", let index = importedManga.firstIndex(where: { $0.id == series.id }) {
            importedManga[index].chapters = Double(localFiles[series.id]?.count ?? 0)
            target = importedManga[index]
        }
        saveLibrary()
        return target
    }

    func removeLocalFile(_ file: LocalChapter, from manga: Manga) {
        if let url = url(for: file) { try? FileManager.default.removeItem(at: url) }
        localFiles[manga.id]?.removeAll { $0.id == file.id }
        if manga.source == "My files", let index = importedManga.firstIndex(where: { $0.id == manga.id }) {
            importedManga[index].chapters = Double(localFiles[manga.id]?.count ?? 0)
        }
        saveLibrary()
    }

    func removeImported() {
        for entry in importedManga {
            library.removeValue(forKey: entry.id)
            lastRead.removeValue(forKey: entry.id)
        }
        importedManga = []
        saveLibrary()
    }

    // MARK: Library persistence

    private struct Snapshot: Codable {
        var version = 1
        var imported: [StoredManga]
        var library: [String: String]
        var lastRead: [String: Double]
        var files: [String: [LocalChapter]]?
        var links: [String: String]?
    }

    private struct StoredManga: Codable {
        var id: String
        var title: String
        var source: String
        var latest: Double
        var status: String
        var addedAt: Date?
        var latestAt: Date?
        var cover: Data?
        var pageURL: String?
    }

    private var libraryFile: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("Dayforge", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }

    func saveLibrary() {
        guard let url = libraryFile else { return }
        let snapshot = Snapshot(
            imported: importedManga.map {
                StoredManga(id: $0.id, title: $0.title, source: $0.source ?? "", latest: $0.chapters, status: $0.status,
                            addedAt: $0.addedAt, latestAt: $0.latestAt, cover: $0.coverData, pageURL: $0.pageURL)
            },
            library: library.mapValues(\.rawValue),
            lastRead: lastRead,
            files: localFiles,
            links: sourceLinks)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Returns false when there is no saved library yet (a fresh install).
    private func loadLibrary() -> Bool {
        guard let url = libraryFile, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return false }
        importedManga = snapshot.imported.map {
            Manga(id: $0.id, title: $0.title, author: $0.source, genre: "Tracked series", chapters: $0.latest,
                  status: $0.status, blurb: $0.source == "My files" ? "Series made from files you added." : "From your MangaPin backup.", chapterTitles: [], art: .paperMoon,
                  coverData: $0.cover, source: $0.source, addedAt: $0.addedAt, latestAt: $0.latestAt,
                  pageURL: $0.pageURL)
        }
        library = snapshot.library.compactMapValues { LibraryStatus(rawValue: $0) }
        lastRead = snapshot.lastRead
        localFiles = snapshot.files ?? [:]
        // Drop links saved from the old (wrong) MangaFire address pattern.
        sourceLinks = (snapshot.links ?? [:]).filter { !$0.value.contains("mangafire.to/manga/") }
        backfillPageURLs()
        return true
    }
}
