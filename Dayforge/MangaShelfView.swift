import SwiftUI
import UniformTypeIdentifiers

/// Discover > Manga Shelf: a library, an updates feed and a browse grid, with a reader behind them.
struct MangaShelfView: View {
    @EnvironmentObject private var app: AppState
    var openManga: (Manga) -> Void

    private enum ShelfTab: String, CaseIterable, Identifiable {
        case library = "Library"
        case updates = "Updates"
        case sources = "Sources"
        var id: String { rawValue }
    }

    @State private var tab: ShelfTab = .library
    @State private var filter: LibraryStatus?
    @State private var showImporter = false
    @State private var showFilePicker = false
    @State private var searchText = ""
    @State private var browser: BrowserTarget?
    @State private var parsedBackup: ParsedBackup?
    @State private var importError: String?
    #if DEBUG
    @State private var didDebugImport = false
    #endif

    private let threeColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let twoColumns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            shelfTabs
            switch tab {
            case .library: library
            case .updates: updates
            case .sources: sources
            }
        }
        .animation(.snappy, value: tab)
        #if DEBUG
        .onAppear {
            // Test hook: launch with `-debugImportPath /path/to/backup.json` to open the import preview directly.
            guard !didDebugImport, let path = UserDefaults.standard.string(forKey: "debugImportPath") else { return }
            didDebugImport = true
            let url = URL(fileURLWithPath: path)
            if let data = try? Data(contentsOf: url) {
                do { parsedBackup = try BackupParser.parse(data, fileName: url.lastPathComponent) } catch { importError = error.localizedDescription }
            }
        }
        #endif
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf, .cbz], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first, let made = app.addLocalFile(from: url, to: nil) {
                openManga(made)
            }
        }
        .fullScreenCover(item: $browser) { target in
            WebBrowserView(start: target.url, seriesID: target.seriesID)
        }
        .sheet(item: $parsedBackup) { backup in
            ImportBackupSheet(backup: backup)
                .presentationDragIndicator(.visible)
        }
        .alert("Couldn't import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            importError = BackupError.unreadable.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importError = BackupError.unreadable.localizedDescription
                return
            }
            do {
                parsedBackup = try BackupParser.parse(data, fileName: url.lastPathComponent)
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    /// Pages come from the source site or your own files, so "read" opens the series' details.
    private func read(_ manga: Manga, chapter: Double) {
        if let target = app.sourceLink(for: manga.id) ?? manga.pageURL.flatMap(URL.init(string:)) {
            browser = BrowserTarget(url: target, seriesID: manga.id)
        } else {
            openManga(manga)
        }
    }

    // MARK: Tabs

    private var shelfTabs: some View {
        HStack(spacing: 6) {
            ForEach(ShelfTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: 6) {
                        Text(item.rawValue)
                        if item == .updates, !app.updates.isEmpty {
                            Text("\(app.updates.count)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.clay, in: Capsule())
                        }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(tab == item ? .white : Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(tab == item ? Theme.ink : Theme.ink.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item == .updates && !app.updates.isEmpty ? "Updates, \(app.updates.count) new" : item.rawValue)
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
            Button {
                showFilePicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.ink.opacity(0.07), in: Circle())
            }
            .accessibilityLabel("Add your own file")
            .accessibilityHint("Pick a PDF or CBZ to read as a new series")
            Button {
                showImporter = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.ink.opacity(0.07), in: Circle())
            }
            .accessibilityLabel("Import MangaPin backup")
            .accessibilityHint("Opens the Files app to pick a backup file")
        }
    }

    // MARK: Library

    @ViewBuilder
    private var library: some View {
        if app.libraryManga.isEmpty {
            VStack(spacing: 14) {
                EmptyStateView(icon: "books.vertical", title: "Your library is empty",
                               message: "Import a MangaPin backup or add your own PDF or CBZ and it shows up here with its progress.")
                Button("Import MangaPin backup") { showImporter = true }
                    .buttonStyle(FilledButtonStyle(tint: Theme.clay))
                Button("Add my own file") { showFilePicker = true }
                    .buttonStyle(SoftButtonStyle(tint: Theme.moss))
            }
            .dayCard()
        } else {
            VStack(alignment: .leading, spacing: 22) {
                if !app.continueReading.isEmpty {
                    continueRow
                }
                filterChips
                libraryGrid
            }
        }
    }

    private var continueRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Continue reading", trailing: "\(app.continueReading.count) in progress")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(app.continueReading) { manga in
                        ContinueCard(manga: manga,
                                     chapter: app.nextChapter(manga),
                                     progress: app.readProgress(manga),
                                     resume: { read(manga, chapter: app.nextChapter(manga)) })
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", count: app.libraryManga.count, selected: filter == nil) { filter = nil }
                ForEach(LibraryStatus.allCases) { status in
                    FilterChip(title: status.title, count: app.libraryManga(filter: status).count,
                               selected: filter == status) { filter = status }
                }
            }
        }
    }

    @ViewBuilder
    private var libraryGrid: some View {
        let items = app.libraryManga(filter: filter)
        if items.isEmpty {
            EmptyStateView(icon: filter?.icon ?? "tray", title: "Nothing in \(filter?.title ?? "your library")",
                           message: "Change a series' status from its details to move it here.")
                .dayCard()
        } else {
            LazyVGrid(columns: threeColumns, spacing: 16) {
                ForEach(items) { manga in
                    LibraryTile(manga: manga, status: app.status(of: manga), unread: app.unread(manga),
                                open: { read(manga, chapter: app.nextChapter(manga)) })
                        .contextMenu {
                            Button { openManga(manga) } label: {
                                Label("Details and progress", systemImage: "slider.horizontal.3")
                            }
                            Button { read(manga, chapter: app.nextChapter(manga)) } label: {
                                Label("Continue reading", systemImage: "book.fill")
                            }
                            ForEach(LibraryStatus.allCases) { status in
                                Button { app.setStatus(manga, status) } label: {
                                    Label(status.title, systemImage: status.icon)
                                }
                            }
                            Button(role: .destructive) { withAnimation { app.setStatus(manga, nil) } } label: {
                                Label("Remove from library", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    // MARK: Updates

    @ViewBuilder
    private var updates: some View {
        let items = app.updates
        if items.isEmpty {
            EmptyStateView(icon: "checkmark.circle", title: "You're all caught up",
                           message: "New chapters from the series in your library will appear here.")
                .dayCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "New chapters", trailing: "\(items.count)")
                }
                ForEach(items) { update in
                    if let manga = app.mangaByID(update.mangaID) {
                        UpdateRow(manga: manga, update: update,
                                  read: { withAnimation(.snappy) { app.markRead(manga, chapter: update.chapter) } },
                                  open: { openManga(manga) })
                    }
                }
                Button {
                    withAnimation(.snappy) { app.markAllUpdatesRead() }
                } label: {
                    Label("Mark all as read", systemImage: "checkmark.circle")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.moss))
                .accessibilityHint("Clears every update")
            }
        }
    }

    // MARK: Browse

    private var sources: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Where to read", trailing: "opens in the app")
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkSoft)
                TextField("Search a title or paste any site", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { if let url = browserURL(from: searchText) { browser = BrowserTarget(url: url) } }
                    .accessibilityLabel("Search a title or enter any site")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))

            ForEach(MangaSource.all) { source in
                Button { browser = BrowserTarget(url: source.searchURL(searchText)) } label: {
                    HStack(spacing: 12) {
                        IconBadge(systemName: source.icon, accent: source.accent, size: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.ink)
                            Text(source.tagline)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .dayCard(padding: 14)
                }
                .accessibilityLabel(searchText.isEmpty ? "Open \(source.name)" : "Search \(source.name) for \(searchText)")
                .buttonStyle(.plain)
                .accessibilityHint("Opens inside Dayforge")
            }

            Button { showFilePicker = true } label: { Label("Read my own PDF or CBZ", systemImage: "doc.badge.plus") }
                .buttonStyle(FilledButtonStyle(tint: Theme.moss))
                .accessibilityHint("Pick a file from the Files app")
        }
    }
}

// MARK: Pieces

struct FilterChip: View {
    var title: String
    var count: Int
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(title) \(count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Theme.ink : Theme.inkSoft)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Theme.yellow.opacity(0.35) : Theme.ink.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(selected ? Theme.yellow : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) series")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct LibraryTile: View {
    var manga: Manga
    var status: LibraryStatus?
    var unread: Int
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    MangaCover(manga: manga, titleSize: 12)
                        .aspectRatio(0.68, contentMode: .fit)
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 24, minHeight: 24)
                            .background(Theme.clay, in: Capsule())
                            .padding(6)
                    }
                }
                if let status {
                    Label(status.title, systemImage: status.icon)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(status.accent.color)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(manga.title), \(status?.title ?? "saved"), \(unread) unread chapters")
        .accessibilityHint("Opens where you left off, or the details if it's new. Long press for more options.")
    }
}

struct ContinueCard: View {
    var manga: Manga
    var chapter: Double
    var progress: Double
    var resume: () -> Void

    var body: some View {
        Button(action: resume) {
            HStack(spacing: 12) {
                MangaCover(manga: manga, titleSize: 10)
                    .frame(width: 64, height: 92)
                VStack(alignment: .leading, spacing: 6) {
                    Text(manga.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("Next: chapter \(chapterText(chapter))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                    ProgressBar(progress: progress, tint: Theme.clay, height: 6)
                        .frame(width: 120)
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.clay)
                }
            }
            .frame(width: 250, alignment: .leading)
            .dayCard(padding: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue \(manga.title), chapter \(chapterText(chapter))")
        .accessibilityValue("\(Int(progress * 100)) percent read")
    }
}

struct UpdateRow: View {
    var manga: Manga
    var update: ChapterUpdate
    var read: () -> Void
    var open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                MangaCover(manga: manga, titleSize: 9)
                    .frame(width: 54, height: 76)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(manga.title)")

            VStack(alignment: .leading, spacing: 3) {
                Text(manga.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Ch. \(chapterText(update.chapter)) · \(update.title)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
                Text(updatedText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.clay)
            }
            Spacer(minLength: 0)
            Button(manga.isImported ? "Mark read" : "Read", action: read)
                .buttonStyle(SoftButtonStyle(tint: Theme.clay))
                .accessibilityLabel("\(manga.isImported ? "Mark" : "Read") chapter \(chapterText(update.chapter)) of \(manga.title)\(manga.isImported ? " as read" : "")")
        }
        .dayCard(padding: 12)
    }
}

extension UpdateRow {
    /// "3d ago" from the real update time when the backup has one, else the hours figure.
    var updatedText: String {
        if let date = update.date {
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        return "\(update.hoursAgo)h ago"
    }
}
