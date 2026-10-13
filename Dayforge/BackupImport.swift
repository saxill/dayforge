import Foundation

/// One series read from a MangaPin backup file (`version` 1: `entries` plus `imgs`).
struct BackupItem: Identifiable, Hashable {
    let id: String
    let name: String
    let siteId: String
    let folder: Int
    /// Latest chapter number the backup knows about.
    let latest: Double
    /// Furthest chapter read, if any.
    let progress: Double?
    /// True when the backup recorded a finish date for the series.
    let finished: Bool
    let addedAt: Date?
    let latestAt: Date?
    let coverData: Data?
    /// The series' own page on its source site, built from the ids in the backup.
    let pageURL: String?

    var sourceName: String {
        switch siteId {
        case "mangafire": return "MangaFire"
        case "mangaplus": return "MANGA Plus"
        default: return siteId.isEmpty ? "MangaPin" : siteId.capitalized
        }
    }

    var addedText: String {
        guard let addedAt else { return "earlier" }
        return addedAt.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

struct ParsedBackup: Identifiable {
    let id = UUID()
    var fileName: String
    var version: Int
    var items: [BackupItem]
    /// Entries that were skipped because they had no id or name.
    var skipped: Int

    var folders: [Int] { Array(Set(items.map(\.folder))).sorted() }

    func items(inFolder folder: Int) -> [BackupItem] { items.filter { $0.folder == folder } }

    /// A best guess at what a folder is, from how its series look:
    /// finished series mean Completed, almost no progress means Plan to read, otherwise Reading.
    func suggestedStatus(forFolder folder: Int) -> LibraryStatus {
        let group = items(inFolder: folder)
        guard !group.isEmpty else { return .planned }
        if group.filter(\.finished).count * 2 >= group.count { return .completed }
        let started = group.filter { ($0.progress ?? 0) > 0 }.count
        return Double(started) / Double(group.count) < 0.25 ? .planned : .reading
    }
}

enum BackupError: LocalizedError {
    case unreadable
    case notJSON
    case notABackup
    case unsupportedVersion(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .unreadable: return "That file couldn't be read."
        case .notJSON: return "That file isn't valid JSON, so it can't be a MangaPin backup."
        case .notABackup: return "That JSON doesn't look like a MangaPin backup (no series list found)."
        case .unsupportedVersion(let v): return "This backup is version \(v). Dayforge reads version 1."
        case .empty: return "The backup has no series in it."
        }
    }
}

enum BackupParser {
    private struct Raw: Decodable {
        var version: Int?
        var entries: [RawEntry]?
        var imgs: [String: String]?
    }

    private struct RawEntry: Decodable {
        var id: String?
        var siteId: String?
        var slug: String?
        var titleId: String?
        var name: String?
        var img: String?
        var folder: Int?
        var latest: RawChapter?
        var progress: RawChapter?
        var startTs: Double?
        var createTs: Double?
        var endTs: Double?
    }

    private struct RawChapter: Decodable {
        var chap: Double?
        var ts: Double?
    }

    static func parse(_ data: Data, fileName: String) throws -> ParsedBackup {
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else { throw BackupError.notJSON }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data), let entries = raw.entries else {
            throw BackupError.notABackup
        }
        let version = raw.version ?? 1
        guard version == 1 else { throw BackupError.unsupportedVersion(version) }
        guard !entries.isEmpty else { throw BackupError.empty }

        var items: [BackupItem] = []
        var skipped = 0
        for entry in entries {
            guard let id = entry.id, !id.isEmpty, let name = entry.name, !name.isEmpty else {
                skipped += 1
                continue
            }
            let cover = entry.img.flatMap { raw.imgs?[$0] }.flatMap { Data(base64Encoded: $0) }
            items.append(BackupItem(
                id: id,
                name: name,
                siteId: entry.siteId ?? "",
                folder: entry.folder ?? 1,
                latest: max(0, entry.latest?.chap ?? 0),
                progress: entry.progress?.chap.map { max(0, $0) },
                finished: entry.endTs != nil,
                addedAt: date(entry.startTs ?? entry.createTs),
                latestAt: date(entry.latest?.ts),
                coverData: cover,
                pageURL: pageURL(site: entry.siteId ?? "", slug: entry.slug, titleId: entry.titleId)))
        }
        guard !items.isEmpty else { throw BackupError.empty }
        return ParsedBackup(fileName: fileName, version: version, items: items, skipped: skipped)
    }

    private static func pageURL(site: String, slug: String?, titleId: String?) -> String? {
        switch site {
        case "mangafire":
            return slug.flatMap { $0.isEmpty ? nil : "https://mangafire.to/title/\($0)" }
        case "mangaplus":
            return titleId.flatMap { $0.isEmpty ? nil : "https://mangaplus.shueisha.co.jp/titles/\($0)" }
        default:
            return nil
        }
    }

    /// Timestamps in the backup are a mix of seconds and milliseconds.
    private static func date(_ value: Double?) -> Date? {
        guard let value, value > 0 else { return nil }
        return Date(timeIntervalSince1970: value > 100_000_000_000 ? value / 1000 : value)
    }
}
