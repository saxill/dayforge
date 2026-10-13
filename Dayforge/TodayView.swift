import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var app: AppState
    var goToFocus: () -> Void
    var goToProfile: () -> Void = {}

    @State private var showExpense = false
    @State private var showBrain = false
    @State private var showPairing = false
    @State private var selectedArticle: AIArticle?

    private enum Anchor: String { case habits, alarm }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    TodayHeader(greeting: greeting, dateText: dateText, openProfile: goToProfile)
                        .padding(.top, 8)

                    PulseCard(onFocus: goToFocus)
                     PartnerStatusCard { showPairing = true }

                    ShortcutGrid(
                        onFocus: goToFocus,
                        onHabits: { withAnimation { proxy.scrollTo(Anchor.habits, anchor: .top) } },
                        onExpense: { showExpense = true },
                        onAlarm: { withAnimation { proxy.scrollTo(Anchor.alarm, anchor: .top) } }
                    )

                    if app.profile.shows(.habits) { HabitsCard().id(Anchor.habits) }
                    if app.profile.shows(.alarm) { AlarmCard().id(Anchor.alarm) }
                    if app.profile.shows(.spending) { SpendingCard(onAdd: { showExpense = true }) }
                    if app.profile.shows(.brain) { BrainTrainingCard(action: { showBrain = true }) }

                    if app.profile.shows(.news), let featured = app.articles.first {
                        SectionHeader(title: "AI news", trailing: "Curated")
                        NewsCard(article: featured) { selectedArticle = featured }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background.ignoresSafeArea())
        .onChange(of: app.requestAddExpense) { _, wanted in
            if wanted { showExpense = true; app.requestAddExpense = false }
        }
        .onAppear {
            if app.requestAddExpense { showExpense = true; app.requestAddExpense = false }
        }
        .sheet(isPresented: $showExpense) {
            AddExpenseSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBrain) {
            BrainTrainingSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPairing) {
            PairingSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailSheet(article: article)
                .presentationDragIndicator(.visible)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        case 17..<22: base = "Good evening"
        default: return "Still up?"
        }
        let name = app.profile.name.split(separator: " ").first.map(String.init) ?? ""
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var dateText: String {
        Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
