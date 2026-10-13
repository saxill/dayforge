import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var app: AppState

    private enum Segment: String, CaseIterable, Identifiable {
        case ai = "AI Brief"
        case manga = "Manga Shelf"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .ai
    @State private var selectedArticle: AIArticle?
    @State private var selectedManga: Manga?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DISCOVER")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Theme.inkSoft)
                    Text("Read something good")
                        .font(Theme.title(30))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Picker("Discover section", selection: $segment) {
                    ForEach(Segment.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Discover section")

                switch segment {
                case .ai: aiBrief
                case .manga:
                    MangaShelfView(openManga: { selectedManga = $0 })
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .animation(.snappy, value: segment)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $selectedArticle) { article in
            ArticleDetailSheet(article: article)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedManga) { manga in
            MangaDetailSheet(manga: manga)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: AI Brief

    @ViewBuilder
    private var aiBrief: some View {
        if app.articles.isEmpty {
            EmptyStateView(icon: "newspaper", title: "No stories yet", message: "Check back later for the next AI brief.")
                .dayCard()
        } else {
            VStack(spacing: 14) {
                ForEach(app.articles) { article in
                    Button {
                        selectedArticle = article
                    } label: {
                        ArticleRow(article: article)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(article.title). \(article.tag). \(article.minutes) minute read.")
                    .accessibilityHint("Opens the story")
                }
            }
        }
    }
}

struct ArticleRow: View {
    var article: AIArticle

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(systemName: article.icon, accent: article.accent, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TagPill(text: article.tag, accent: article.accent)
                    Text("\(article.minutes) min")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                }
                Text(article.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
        }
        .dayCard(padding: 14)
    }
}
