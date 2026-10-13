import SwiftUI
import PDFKit
import Compression

/// Reads the pages out of a CBZ (a zip of images). Handles stored and deflated entries; zip64 is not supported.
struct ComicArchive {
    struct Page: Identifiable {
        let id: Int
        let name: String
        fileprivate let method: UInt16
        fileprivate let compressedSize: Int
        fileprivate let uncompressedSize: Int
        fileprivate let dataStart: Int
    }

    let data: Data
    let pages: [Page]

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count > 22 else { return nil }
        self.data = data

        func u16(_ at: Int) -> Int { Int(data[at]) | Int(data[at + 1]) << 8 }
        func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }

        // End of central directory record: scan back for its signature.
        var eocd = -1
        var i = data.count - 22
        while i >= max(0, data.count - 65_557) {
            if u32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { return nil }
        let count = u16(eocd + 10)
        var cursor = u32(eocd + 16)

        let imageTypes: Set<String> = ["jpg", "jpeg", "png", "webp", "gif"]
        var found: [(name: String, page: Page)] = []
        for _ in 0..<count {
            guard cursor + 46 <= data.count, u32(cursor) == 0x02014b50 else { break }
            let method = UInt16(u16(cursor + 10))
            let compressed = u32(cursor + 20)
            let uncompressed = u32(cursor + 24)
            let nameLength = u16(cursor + 28)
            let extraLength = u16(cursor + 30)
            let commentLength = u16(cursor + 32)
            let localOffset = u32(cursor + 42)
            let nameData = data.subdata(in: (cursor + 46)..<min(data.count, cursor + 46 + nameLength))
            let name = String(decoding: nameData, as: UTF8.self)
            cursor += 46 + nameLength + extraLength + commentLength

            let ext = (name as NSString).pathExtension.lowercased()
            let base = (name as NSString).lastPathComponent
            guard imageTypes.contains(ext), !name.hasPrefix("__MACOSX"), !base.hasPrefix("."),
                  localOffset + 30 <= data.count, u32(localOffset) == 0x04034b50 else { continue }
            let start = localOffset + 30 + u16(localOffset + 26) + u16(localOffset + 28)
            found.append((name, Page(id: 0, name: name, method: method, compressedSize: compressed,
                                     uncompressedSize: uncompressed, dataStart: start)))
        }
        found.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        pages = found.enumerated().map { index, entry in
            Page(id: index, name: entry.name, method: entry.page.method, compressedSize: entry.page.compressedSize,
                 uncompressedSize: entry.page.uncompressedSize, dataStart: entry.page.dataStart)
        }
        if pages.isEmpty { return nil }
    }

    func image(for page: Page) -> UIImage? {
        let end = page.dataStart + page.compressedSize
        guard page.dataStart >= 0, end <= data.count else { return nil }
        let raw = data.subdata(in: page.dataStart..<end)
        switch page.method {
        case 0:
            return UIImage(data: raw)
        case 8:
            var output = [UInt8](repeating: 0, count: max(page.uncompressedSize, 1))
            let written = raw.withUnsafeBytes { source -> Int in
                guard let base = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(&output, output.count, base, raw.count, nil, COMPRESSION_ZLIB)
            }
            guard written > 0 else { return nil }
            return UIImage(data: Data(output.prefix(written)))
        default:
            return nil
        }
    }
}

/// Full-screen reader for a PDF or CBZ you added. Marks progress when you finish.
struct LocalReaderView: View {
    var manga: Manga
    var file: LocalChapter
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var archive: ComicArchive?
    @State private var pdf: PDFDocument?
    @State private var failed = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            content
            topBar
        }
        .preferredColorScheme(.dark)
        .task { load() }
    }

    @ViewBuilder
    private var content: some View {
        if let pdf {
            PDFReader(document: pdf)
                .ignoresSafeArea(edges: .bottom)
                .padding(.top, 58)
        } else if let archive {
            ScrollView {
                LazyVStack(spacing: 4) {
                    Color.clear.frame(height: 58)
                    ForEach(archive.pages) { page in
                        ArchivePageView(archive: archive, page: page, total: archive.pages.count)
                    }
                    finishButton.padding(24)
                }
            }
            .scrollIndicators(.hidden)
        } else if failed {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 30))
                Text("This file couldn't be opened.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("Dayforge reads PDF and CBZ files.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .frame(maxHeight: .infinity)
        } else {
            ProgressView().tint(.white).frame(maxHeight: .infinity)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.14), in: Circle())
            }
            .accessibilityLabel("Close reader")
            VStack(alignment: .leading, spacing: 1) {
                Text(manga.title).font(.system(size: 15, weight: .bold, design: .rounded)).lineLimit(1)
                Text(file.name).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            }
            Spacer()
            if pdf != nil { finishCompact }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.85))
    }

    private var finishButton: some View {
        Button { finish() } label: { Label("Mark as read", systemImage: "checkmark.circle.fill") }
            .buttonStyle(FilledButtonStyle(tint: Theme.moss))
    }

    private var finishCompact: some View {
        Button { finish() } label: { Label("Done", systemImage: "checkmark.circle.fill") }
            .buttonStyle(SoftButtonStyle(tint: .white))
    }

    private func finish() {
        let index = (app.localFiles[manga.id] ?? []).firstIndex(of: file).map { $0 + 1 } ?? 1
        if manga.source == "My files" { app.markRead(manga, chapter: Double(index)) }
        dismiss()
    }

    private func load() {
        guard archive == nil, pdf == nil, let url = app.url(for: file) else { failed = true; return }
        if file.isPDF {
            if let document = PDFDocument(url: url) { pdf = document } else { failed = true }
        } else if let opened = ComicArchive(url: url) {
            archive = opened
        } else {
            failed = true
        }
    }
}

private struct ArchivePageView: View {
    var archive: ComicArchive
    var page: ComicArchive.Page
    var total: Int
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color.white.opacity(0.06).aspectRatio(0.7, contentMode: .fit)
                    .overlay(ProgressView().tint(.white))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Page \(page.id + 1) of \(total)")
        .task {
            if image == nil { image = archive.image(for: page) }
        }
        .onDisappear { image = nil }
    }
}

private struct PDFReader: UIViewRepresentable {
    var document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
