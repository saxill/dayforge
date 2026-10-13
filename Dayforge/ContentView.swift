import SwiftUI

enum AppTab: Hashable {
    case today, focus, discover, profile
}

struct ContentView: View {
    @StateObject private var app = AppState()
    @State private var tab: AppTab = .today
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    private var splash: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("D")
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 130, height: 130)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                Text("Dayforge").font(Theme.title(30)).foregroundStyle(Theme.ink)
            }
        }
        .transition(.opacity)
        .accessibilityHidden(true)
    }

    var body: some View {
        TabView(selection: $tab) {
            TodayView(goToFocus: { tab = .focus }, goToProfile: { tab = .profile })
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(AppTab.today)

            FocusView(timer: app.focus)
                .tabItem { Label("Focus", systemImage: "timer") }
                .tag(AppTab.focus)

            DiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles") }
                .tag(AppTab.discover)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .id(app.profile.theme)
        .environmentObject(app)
        .tint(Theme.moss)
        .overlay { if showSplash { splash } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                app.drainPending()
                if app.requestAddExpense { tab = .today }
                if app.account != nil {
                    Task {
                        await app.refreshPair()
                        await app.publishMotivation()
                    }
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
        }
    }
}

#Preview {
    ContentView()
}
