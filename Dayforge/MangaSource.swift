import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// Comic book archive: a zip of page images.
    static let cbz = UTType(filenameExtension: "cbz", conformingTo: .archive) ?? .zip
}

/// A website where a series can be read. Dayforge only opens it in the browser.
struct MangaSource: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let icon: String
    let accent: Accent
    private let searchBase: String
    private let home: String

    func searchURL(_ title: String) -> URL {
        let query = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return URL(string: home) ?? URL(string: "https://example.com")! }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: searchBase + encoded) ?? URL(string: home)!
    }

    static let mangaPlus = MangaSource(
        id: "mangaplus", name: "MANGA Plus", tagline: "Official Shueisha reader. Free latest chapters.",
        icon: "checkmark.seal.fill", accent: .moss,
        searchBase: "https://mangaplus.shueisha.co.jp/search_result?keyword=", home: "https://mangaplus.shueisha.co.jp")
    static let mangaFire = MangaSource(
        id: "mangafire", name: "MangaFire", tagline: "The source most of your backup was tracked on.",
        icon: "flame.fill", accent: .clay,
        searchBase: "https://mangafire.to/filter?keyword=", home: "https://mangafire.to")
    static let mangaDex = MangaSource(
        id: "mangadex", name: "MangaDex", tagline: "Community library with official publisher uploads.",
        icon: "books.vertical.fill", accent: .blue,
        searchBase: "https://mangadex.org/search?q=", home: "https://mangadex.org")

    static let all: [MangaSource] = [mangaPlus, mangaFire, mangaDex]

    /// The series' own source first (when known), then MANGA Plus, then the rest.
    static func options(for source: String?) -> [MangaSource] {
        guard let source, let own = all.first(where: { $0.name == source }) else { return [mangaPlus, mangaDex] }
        return [own] + all.filter { $0 != own && $0 == mangaPlus } + all.filter { $0 != own && $0 != mangaPlus && $0 == mangaDex }
    }
}
