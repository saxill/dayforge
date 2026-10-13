import SwiftUI
import UniformTypeIdentifiers

struct ArticleDetailSheet: View {
    var article: AIArticle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        IconBadge(systemName: article.icon, accent: article.accent, size: 46)
                        TagPill(text: article.tag, accent: article.accent)
                        Text("\(article.minutes) min read")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.inkSoft)
                    }

                    Text(article.title)
                        .font(Theme.title(28))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(article.summary)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.system(size: 17, design: .serif))
                            .lineSpacing(5)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Sample story written for Dayforge. Not real news.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 8)
                }
                .padding(22)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("AI Brief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct MangaDetailSheet: View {
    var manga: Manga
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var reader: LocalChapter?
    @State private var showFilePicker = false
    @State private var browser: BrowserTarget?

    private var status: LibraryStatus? { app.status(of: manga) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MangaCover(manga: manga, titleSize: 26)
                        .frame(height: 300)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(manga.title)
                            .font(Theme.title(28))
                            .foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("by \(manga.author)")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Theme.inkSoft)
                        HStack(spacing: 8) {
                            TagPill(text: manga.genre, accent: .blue)
                            TagPill(text: manga.status, accent: manga.status == "Completed" ? .moss : .clay)
                            TagPill(text: "\(chapterText(manga.chapters)) chapters", accent: .yellow)
                        }
                        .padding(.top, 4)
                    }

                    Text(manga.blurb)
                        .font(.system(size: 16, design: .rounded))
                        .lineSpacing(4)
                        .foregroundStyle(Theme.ink)

                    if status != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressBar(progress: app.readProgress(manga), tint: Theme.clay)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Reading progress")
                                .accessibilityValue("\(Int(app.readProgress(manga) * 100)) percent")
                            Text("\(chapterText(app.chaptersRead(manga))) of \(chapterText(manga.chapters)) chapters read")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }

                    progressControls

                    readOnline

                    myFiles

                    libraryMenu

                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Manga")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .fullScreenCover(item: $browser) { target in
                WebBrowserView(start: target.url, seriesID: target.seriesID)
            }
            .fullScreenCover(item: $reader) { file in
                LocalReaderView(manga: manga, file: file)
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf, .cbz], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    for url in urls { app.addLocalFile(from: url, to: manga) }
                }
            }
        }
    }

    /// Opens the series on its own source and on the official MANGA Plus site. Dayforge only links out.
    private var readOnline: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Read online")
            if let saved = app.sourceLink(for: manga.id) ?? manga.pageURL.flatMap(URL.init(string:)) {
                Button { browser = BrowserTarget(url: saved, seriesID: manga.id) } label: {
                    Label(app.sourceLink(for: manga.id) == nil ? "Open the manga page" : "Continue where you left off", systemImage: "play.fill")
                }
                .buttonStyle(FilledButtonStyle(tint: Theme.clay))
                .accessibilityHint("Opens \(saved.host ?? "the site") on the last page you had open")
            }
            ForEach(MangaSource.options(for: manga.source)) { source in
                Button {
                    let own = source.name == manga.source ? manga.pageURL.flatMap(URL.init(string:)) : nil
                    browser = BrowserTarget(url: own ?? source.searchURL(manga.title), seriesID: manga.id)
                } label: {
                    HStack(spacing: 12) {
                        IconBadge(systemName: source.icon, accent: source.accent, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.name == manga.source ? "Read on \(source.name)" : "Find on \(source.name)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.ink)
                            Text(source.tagline)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(manga.title) on \(source.name)")
                .accessibilityHint("Opens inside Dayforge")
            }
            Button { browser = BrowserTarget(url: URL(string: "https://duckduckgo.com/?q=" + (manga.title + " manga read").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!) } label: {
                Label("Search anywhere else", systemImage: "globe")
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.blue))
            .accessibilityHint("Searches the web for this title inside Dayforge")
        }
        .dayCard(padding: 14)
    }

    /// PDF and CBZ files you added for this series, readable inside Dayforge.
    private var myFiles: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "My files", trailing: "\((app.localFiles[manga.id] ?? []).count)")
            ForEach(app.localFiles[manga.id] ?? []) { file in
                Button { reader = file } label: {
                    HStack(spacing: 10) {
                        Image(systemName: file.isPDF ? "doc.richtext.fill" : "books.vertical.fill")
                            .foregroundStyle(Theme.moss)
                        Text(file.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "book.fill").foregroundStyle(Theme.clay)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) { app.removeLocalFile(file, from: manga) } label: {
                        Label("Remove file", systemImage: "trash")
                    }
                }
                .accessibilityLabel("Read \(file.name)")
                .accessibilityHint("Opens the reader. Long press to remove.")
            }
            Button { showFilePicker = true } label: { Label("Add a PDF or CBZ", systemImage: "plus.circle.fill") }
                .buttonStyle(SoftButtonStyle(tint: Theme.moss))
                .accessibilityHint("Pick a file from the Files app to read here")
        }
        .dayCard(padding: 14)
    }

    /// Progress for imported series: step the chapter count or jump to the latest.
    private var progressControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chapters read")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button {
                    app.setProgress(manga, to: app.chaptersRead(manga).rounded(.down) - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 40, height: 40)
                        .background(Theme.ink.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("One chapter less")
                Text(chapterText(app.chaptersRead(manga)))
                    .font(Theme.number(22))
                    .frame(minWidth: 52)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(chapterText(app.chaptersRead(manga))) chapters read")
                Button {
                    app.setProgress(manga, to: app.chaptersRead(manga).rounded(.down) + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 40, height: 40)
                        .background(Theme.clay.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("One chapter more")
            }
            .foregroundStyle(Theme.ink)
            Button {
                withAnimation(.snappy) { app.setProgress(manga, to: manga.chapters) }
            } label: {
                Label("Mark up to chapter \(chapterText(manga.chapters))", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(FilledButtonStyle(tint: Theme.moss))
            .accessibilityHint("Sets your progress to the latest chapter")
        }
        .dayCard(padding: 14)
    }

    private var libraryMenu: some View {
        Menu {
            ForEach(LibraryStatus.allCases) { item in
                Button {
                    app.setStatus(manga, item)
                } label: {
                    Label(item.title, systemImage: status == item ? "checkmark" : item.icon)
                }
            }
            if status != nil {
                Divider()
                Button(role: .destructive) {
                    app.setStatus(manga, nil)
                } label: {
                    Label("Remove from library", systemImage: "trash")
                }
            }
        } label: {
            Label(status?.title ?? "Add to library", systemImage: status?.icon ?? "plus.circle.fill")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(status?.accent.color ?? Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background((status?.accent.color ?? Theme.ink).opacity(0.12), in: Capsule())
        }
        .accessibilityLabel(status == nil ? "Add to library" : "Library status: \(status?.title ?? "")")
        .accessibilityHint("Choose a status or remove it")
    }
}
