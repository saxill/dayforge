import SwiftUI
import UIKit

struct PairingSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var joinCode = ""
    @State private var nudgeMessage = ""
    @State private var copied = false
    @State private var confirmLeave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro

                    if let pair = app.pair {
                        if pair.status == "waiting" {
                            waitingContent(pair)
                        } else {
                            connectedContent(pair)
                        }
                    } else {
                        unpairedContent
                    }

                    if let error = app.pairError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.clay)
                            .accessibilityLabel("Team error: \(error)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Motivation partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if app.account != nil { await app.refreshPair() }
            }
            .alert("Leave this team?", isPresented: $confirmLeave) {
                Button("Leave team", role: .destructive) {
                    Task { await app.leavePair() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your motivation summaries will stop being shared with this partner. Your Dayforge data stays on this phone.")
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forge a little momentum together")
                .font(Theme.title(24))
                .foregroundStyle(Theme.ink)
            Text("Share daily ritual totals, focus and Pulse with one person. Habit definitions, names and IDs, expenses, alarms, manga, notes and other private data stay private.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    private var unpairedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Start a team", trailing: "two people")
            Text("Create a private code for someone you trust, or enter the code they shared with you.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.inkSoft)

            Button {
                Task { await app.createPairInvite() }
            } label: {
                if app.pairLoading {
                    ProgressView().tint(.white)
                } else {
                    Label("Create team code", systemImage: "person.2.fill")
                }
            }
            .buttonStyle(FilledButtonStyle(tint: Theme.moss))
            .disabled(app.pairLoading)
            .accessibilityLabel("Create team code")
            .accessibilityHint("Creates a private code for your motivation partner")

            VStack(alignment: .leading, spacing: 10) {
                Text("Have a code?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                TextField("6-character code", text: codeBinding)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospaced())
                    .tracking(2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
                     .accessibilityLabel("Team code")
                     .accessibilityHint("Enter a 6 character uppercase code")

                Button {
                    Task { await app.joinPair(code: joinCode) }
                } label: {
                    if app.pairLoading {
                        ProgressView()
                    } else {
                        Label("Join with code", systemImage: "arrow.right.circle.fill")
                    }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue))
                .disabled(!validCode || app.pairLoading)
                .opacity(validCode ? 1 : 0.5)
                .accessibilityLabel("Join with code")
                .accessibilityHint("Joins the team using the entered code")
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        }
        .dayCard()
    }

    private func waitingContent(_ pair: PairPayload) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Your team code", trailing: "waiting")
                Spacer(minLength: 0)
            }

            Text(pair.code ?? "—")
                .font(.system(size: 42, weight: .heavy, design: .rounded).monospaced())
                .tracking(5)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .accessibilityLabel("Team code \(pair.code ?? "not available")")

            Text("Share this code with your motivation partner. Dayforge will keep the team ready while they join.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.inkSoft)

            HStack(spacing: 10) {
                Button {
                    if let code = pair.code { copyCode(code) }
                } label: {
                    Label(copied ? "Copied" : "Copy code", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(FilledButtonStyle(tint: Theme.moss))
                .accessibilityLabel(copied ? "Team code copied" : "Copy team code")

                Button {
                    Task { await app.refreshPair() }
                } label: {
                    if app.pairLoading { ProgressView() } else { Label("Refresh", systemImage: "arrow.clockwise") }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue))
                .disabled(app.pairLoading)
                .accessibilityLabel("Refresh team status")
            }
        }
        .dayCard()
    }

    private func connectedContent(_ pair: PairPayload) -> some View {
        let mine = app.localMotivationSummary
        let partner = partnerSummary(for: pair)
        let partnerName = pair.partnerName ?? partner?.name ?? "Your partner"

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.moss, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(partnerName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Motivation partner")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                    Text(partnerStatus(partner))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.blue)
                }
                Spacer(minLength: 0)
                TagPill(text: "Connected", accent: .moss)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Connected to \(partnerName) as your motivation partner")

            HStack(spacing: 10) {
                MotivationScoreView(title: "Your Pulse", score: mine.pulse, tint: Theme.moss)
                MotivationScoreView(title: "\(partnerName)'s Pulse", score: partner?.pulse, tint: Theme.blue)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Momentum snapshot")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                MotivationMetricRow(
                    title: "Rituals aggregate",
                    mine: "\(mine.habitsDone)/\(mine.habitsTotal)",
                    partner: partner.map { "\($0.habitsDone)/\($0.habitsTotal)" } ?? "—"
                )
                MotivationMetricRow(
                    title: "Focus",
                    mine: "\(mine.focusMinutes) min",
                    partner: partner.map { "\($0.focusMinutes) min" } ?? "—"
                )
                MotivationMetricRow(
                    title: "Focus streak",
                    mine: "\(mine.focusStreakDays) days",
                    partner: partner.map { "\($0.focusStreakDays) days" } ?? "—"
                )
            }
            .padding(14)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let partner {
                PartnerHistoryView(summary: partner)
            } else {
                Text("Your partner's daily status will appear here after their first check-in.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 2)
            }

            nudgeContent

            HStack(spacing: 10) {
                Button {
                    Task { await app.refreshPair() }
                } label: {
                    if app.pairLoading { ProgressView() } else { Label("Refresh", systemImage: "arrow.clockwise") }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue))
                .disabled(app.pairLoading)
                .accessibilityLabel("Refresh motivation partner")

                Button("Leave team", role: .destructive) { confirmLeave = true }
                    .buttonStyle(SoftButtonStyle(tint: Theme.clay))
                    .disabled(app.pairLoading)
                    .accessibilityLabel("Leave team")
                    .accessibilityHint("Asks for confirmation before disconnecting your motivation partner")
            }
        }
        .dayCard()
    }

    private var nudgeContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Encouragement")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            if let nudge = app.latestNudge {
                Text("\(nudge.fromName): \(nudge.message)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Latest encouragement from \(nudge.fromName): \(nudge.message)")
            } else {
                Text("No encouragement yet. A small check-in can change the shape of a day.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
            }

            TextField("Send a short boost", text: nudgeBinding)
                .font(.system(size: 15, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
                .accessibilityLabel("Encouragement message")
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)

            Button {
                Task {
                    await app.sendPairNudge(message: nudgeMessage)
                    if app.pairError == nil { nudgeMessage = "" }
                }
            } label: {
                if app.pairLoading { ProgressView() } else { Label("Send encouragement", systemImage: "paperplane.fill") }
            }
            .buttonStyle(FilledButtonStyle(tint: Theme.moss))
            .disabled(nudgeMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || app.pairLoading)
            .opacity(nudgeMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .accessibilityLabel("Send encouragement")
        }
        .padding(14)
        .background(Theme.moss.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var codeBinding: Binding<String> {
        Binding(
            get: { joinCode },
            set: { value in
                let scalars = value.uppercased().unicodeScalars.filter {
                    (48...57).contains($0.value) || (65...90).contains($0.value)
                }
                joinCode = String(scalars.prefix(8))
            }
        )
    }

    private var nudgeBinding: Binding<String> {
        Binding(
            get: { nudgeMessage },
                 set: { nudgeMessage = String($0.prefix(120)) }
        )
    }

    private var validCode: Bool {
        guard joinCode.count == 6 else { return false }
        return joinCode.unicodeScalars.allSatisfy {
            (48...57).contains($0.value) || (65...90).contains($0.value)
        }
    }

    private func partnerSummary(for pair: PairPayload) -> MotivationSummary? {
        if let partnerID = pair.partnerUserId,
           let exact = app.pairSummaries.first(where: { $0.userId == partnerID }) {
            return exact
        }
        let localName = app.localMotivationSummary.name
        return app.pairSummaries.first(where: { $0.name != localName }) ?? app.pairSummaries.first
    }

    private func partnerStatus(_ summary: MotivationSummary?) -> String {
        guard let summary else { return "Waiting for a daily check-in" }
        if summary.checkedInDate == PairingDate.string() { return "Checked in today" }
        if let date = summary.checkedInDate { return "Last check-in \(date)" }
        return "No check-in yet"
    }

    @MainActor
    private func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }
}

private struct MotivationScoreView: View {
    var title: String
    var score: Int?
    var tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(score.map { String($0) } ?? "—")
                .font(Theme.number(30))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(score.map { String($0) } ?? "not available")")
    }
}

private struct MotivationMetricRow: View {
    var title: String
    var mine: String
    var partner: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(mine)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(width: 76, alignment: .trailing)
            Text(partner)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.blue)
                .frame(width: 76, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): you \(mine), partner \(partner)")
    }
}

private struct PartnerHistoryView: View {
    let summary: MotivationSummary
    @State private var days = 7

    private var entries: [DayforgeHistoryEntry] {
        Array(summary.history.sorted { $0.date > $1.date }.prefix(days))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily history")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("aggregate only")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
            }

            Picker("History range", selection: $days) {
                Text("Last 7 days").tag(7)
                Text("Last 30 days").tag(30)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Partner history range")

            if entries.isEmpty {
                Text("No daily history yet.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 12) {
                    ForEach(entries) { entry in
                        PartnerHistoryRow(entry: entry)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct PartnerHistoryRow: View {
    let entry: DayforgeHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(entry.date)
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("Pulse \(entry.pulse)")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.moss)
            }

            ProgressBar(progress: Double(entry.pulse) / 100, tint: Theme.moss, height: 7)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Pulse on \(entry.date)")
                .accessibilityValue("\(entry.pulse) out of 100")

            HStack(spacing: 14) {
                Label("Rituals \(entry.habitsDone)/\(entry.habitsTotal)", systemImage: "checkmark.circle")
                Label("Focus \(entry.focusMinutes) min", systemImage: "timer")
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.inkSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.date), Pulse \(entry.pulse), rituals \(entry.habitsDone) of \(entry.habitsTotal), focus \(entry.focusMinutes) minutes")
    }
}

struct PartnerStatusCard: View {
    @EnvironmentObject private var app: AppState
    var open: () -> Void

    var body: some View {
        if app.account != nil {
            Button(action: open) {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 42, height: 42)
                        .background(iconColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .dayCard(padding: 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityTitle)
            .accessibilityHint("Opens your private motivation team")
        }
    }

    private var pair: PairPayload? { app.pair }

    private var partner: MotivationSummary? {
        guard let pair else { return nil }
        return partnerSummary(for: pair)
    }

    private var iconName: String {
        guard let pair else { return "person.2.badge.plus" }
        return pair.status == "waiting" ? "person.2.badge.plus" : "person.2.fill"
    }

    private var iconColor: Color {
        guard let pair else { return Theme.moss }
        return pair.status == "waiting" ? Theme.clay : Theme.moss
    }

    private var title: String {
        guard let pair else { return "Motivation partner" }
        if pair.status == "waiting" { return "Team code ready" }
        return pair.partnerName ?? partner?.name ?? "Motivation partner"
    }

    private var subtitle: String {
        guard let pair else { return "Set up a private team" }
        if pair.status == "waiting" { return "Share \(pair.code ?? "your code") to connect" }
        guard let partner else { return "Waiting for a daily check-in" }
        let historyCount = partner.history.count
        return "Pulse \(partner.pulse) · Rituals \(partner.habitsDone)/\(partner.habitsTotal) · \(historyCount) days logged"
    }

    private var accessibilityTitle: String {
        guard let pair else { return "Set up a motivation partner" }
        return pair.status == "waiting" ? "Team code ready" : "Open motivation partner"
    }

    private func partnerSummary(for pair: PairPayload) -> MotivationSummary? {
        if let partnerID = pair.partnerUserId,
           let exact = app.pairSummaries.first(where: { $0.userId == partnerID }) {
            return exact
        }
        let localName = app.localMotivationSummary.name
        return app.pairSummaries.first(where: { $0.name != localName }) ?? app.pairSummaries.first
    }
}
