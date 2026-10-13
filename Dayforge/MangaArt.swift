import SwiftUI
import UIKit

// MARK: Reusable shapes

struct WaveShape: Shape {
    var amplitude: CGFloat
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        var x: CGFloat = 0
        while x <= rect.width {
            let y = rect.midY + sin((x / rect.width) * .pi * 3 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 4
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct RoofLine: Shape {
    var steps: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        let step = rect.width / CGFloat(steps)
        for i in 0..<steps {
            let x = CGFloat(i) * step
            let h = rect.height * (i % 2 == 0 ? 0.55 : 0.8)
            path.addLine(to: CGPoint(x: x, y: rect.maxY - h))
            path.addLine(to: CGPoint(x: x + step * 0.5, y: rect.maxY - h - rect.height * 0.18))
            path.addLine(to: CGPoint(x: x + step, y: rect.maxY - h))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.midY))
        return path
    }
}

// MARK: Cover art

/// Original cover artwork for the sample shelf, drawn only with gradients and shapes.
struct MangaArtView: View {
    var style: MangaArtStyle

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                switch style {
                case .lanternHollow: lanternHollow(w, h)
                case .tideAndTinder: tideAndTinder(w, h)
                case .quietRail: quietRail(w, h)
                case .glassOrchard: glassOrchard(w, h)
                case .emberParade: emberParade(w, h)
                case .paperMoon: paperMoon(w, h)
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    // Night harbour with a moon and a string of lanterns.
    private func lanternHollow(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B2340), Color(hex: 0x3E4C73)], startPoint: .top, endPoint: .bottom)
            Circle().fill(Color(hex: 0xF3E7C4)).frame(width: w * 0.42, height: w * 0.42).position(x: w * 0.7, y: h * 0.26)
            Circle().fill(Color(hex: 0xF3E7C4).opacity(0.18)).frame(width: w * 0.62, height: w * 0.62).position(x: w * 0.7, y: h * 0.26)
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: 0xE08A52))
                    .frame(width: w * 0.09, height: w * 0.13)
                    .shadow(color: Color(hex: 0xE08A52).opacity(0.8), radius: 8)
                    .position(x: w * (0.14 + 0.18 * CGFloat(i)), y: h * (0.5 + 0.03 * CGFloat(i % 2)))
            }
            RoofLine(steps: 5).fill(Color(hex: 0x0F1530)).frame(height: h * 0.34).position(x: w / 2, y: h * 0.83)
        }
    }

    // Warm sea at sunrise with a little triangular sail.
    private func tideAndTinder(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF6C28B), Color(hex: 0xE8806A)], startPoint: .top, endPoint: .bottom)
            Circle().fill(Color(hex: 0xFFF1C9)).frame(width: w * 0.36, height: w * 0.36).position(x: w * 0.3, y: h * 0.4)
            WaveShape(amplitude: h * 0.025, phase: 0).fill(Color(hex: 0x2E6F8E)).frame(height: h * 0.42).position(x: w / 2, y: h * 0.72)
            WaveShape(amplitude: h * 0.03, phase: 1.6).fill(Color(hex: 0x1F4F6B)).frame(height: h * 0.32).position(x: w / 2, y: h * 0.84)
            TriangleShape().fill(Color(hex: 0xFDF3DC)).frame(width: w * 0.2, height: w * 0.26).position(x: w * 0.66, y: h * 0.58)
            Rectangle().fill(Color(hex: 0x5A3A2B)).frame(width: 3, height: w * 0.08).position(x: w * 0.66, y: h * 0.69)
        }
    }

    // A night train with lit windows on a track under the stars.
    private func quietRail(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x16313A), Color(hex: 0x2F5C63)], startPoint: .top, endPoint: .bottom)
            ForEach(0..<9, id: \.self) { i in
                Circle().fill(.white.opacity(0.75))
                    .frame(width: i % 3 == 0 ? 4 : 2.5, height: i % 3 == 0 ? 4 : 2.5)
                    .position(x: w * (0.1 + 0.1 * CGFloat(i)), y: h * (0.12 + 0.07 * CGFloat((i * 5) % 4)))
            }
            Rectangle().fill(Color(hex: 0x0D1B20)).frame(height: h * 0.1).position(x: w / 2, y: h * 0.86)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(hex: 0xB8553D))
                        .frame(width: w * 0.28, height: h * 0.2)
                        .overlay(
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xFFE9A8)).frame(width: w * 0.055, height: h * 0.07)
                                }
                            }
                        )
                }
            }
            .position(x: w / 2, y: h * 0.7)
        }
    }

    // Glass fruit trees on rolling hills.
    private func glassOrchard(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xD6EBD3), Color(hex: 0x8DBFA0)], startPoint: .top, endPoint: .bottom)
            WaveShape(amplitude: h * 0.04, phase: 0.6).fill(Color(hex: 0x4F8A6A)).frame(height: h * 0.45).position(x: w / 2, y: h * 0.8)
            ForEach(0..<3, id: \.self) { i in
                let x = w * (0.2 + 0.3 * CGFloat(i))
                let y = h * (0.5 + 0.04 * CGFloat(i % 2))
                Rectangle().fill(Color(hex: 0x6B4F3A)).frame(width: w * 0.04, height: h * 0.2).position(x: x, y: y + h * 0.11)
                Circle().fill(Color.white.opacity(0.55)).frame(width: w * 0.24, height: w * 0.24).position(x: x, y: y - h * 0.02)
                Circle().stroke(Color.white.opacity(0.9), lineWidth: 2).frame(width: w * 0.24, height: w * 0.24).position(x: x, y: y - h * 0.02)
                Circle().fill(Color(hex: 0xE5A04B).opacity(0.85)).frame(width: w * 0.07, height: w * 0.07).position(x: x + w * 0.04, y: y)
            }
        }
    }

    // Festival night with sparks.
    private func emberParade(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x3B1F3A), Color(hex: 0xB5473E)], startPoint: .top, endPoint: .bottom)
            ForEach(0..<7, id: \.self) { i in
                SparkShape()
                    .fill(Color(hex: i % 2 == 0 ? 0xFFD36B : 0xFFF1C9))
                    .frame(width: w * (i % 3 == 0 ? 0.16 : 0.1), height: w * (i % 3 == 0 ? 0.16 : 0.1))
                    .position(x: w * (0.15 + 0.12 * CGFloat(i)), y: h * (0.22 + 0.12 * CGFloat((i * 3) % 4)))
            }
            RoofLine(steps: 4).fill(Color(hex: 0x1D0F20)).frame(height: h * 0.28).position(x: w / 2, y: h * 0.86)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: 0xF2B84B)).frame(width: w * 0.46, height: h * 0.14).position(x: w * 0.5, y: h * 0.66)
        }
    }

    // A paper moon over folded streets.
    private func paperMoon(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF4EEDC), Color(hex: 0xD9C9A6)], startPoint: .top, endPoint: .bottom)
            Circle().fill(Color(hex: 0xFFFDF4)).frame(width: w * 0.5, height: w * 0.5).position(x: w * 0.62, y: h * 0.3)
                .shadow(color: .black.opacity(0.12), radius: 6, x: 3, y: 6)
            ForEach(0..<4, id: \.self) { i in
                TriangleShape()
                    .fill(Color(hex: i % 2 == 0 ? 0x44627A : 0x5E8199))
                    .frame(width: w * 0.34, height: h * (0.3 + 0.05 * CGFloat(i % 2)))
                    .position(x: w * (0.14 + 0.24 * CGFloat(i)), y: h * 0.78)
            }
            Capsule().fill(Color(hex: 0xC9593F)).frame(width: w * 0.2, height: 5).rotationEffect(.degrees(-12)).position(x: w * 0.3, y: h * 0.52)
        }
    }
}

/// A book cover: artwork plus the title set on a dark footer.
struct MangaCover: View {
    var manga: Manga
    var titleSize: CGFloat = 15

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CoverArt(manga: manga)
            LinearGradient(colors: [.clear, Theme.deep.opacity(0.72)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(manga.title)
                    .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(manga.genre.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
    }
}

/// Decoded cover images, so scrolling a grid never decodes the same WebP twice.
enum CoverImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for id: String, data: Data) -> UIImage? {
        if let hit = cache.object(forKey: id as NSString) { return hit }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: id as NSString)
        return image
    }
}

/// The picture behind a cover: the real image for imported series, original shape art for the samples,
/// and a palette gradient when an imported series has no image.
struct CoverArt: View {
    var manga: Manga

    var body: some View {
        GeometryReader { proxy in
            if let data = manga.coverData, let image = CoverImageCache.image(for: manga.id, data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else if manga.isImported {
                placeholder.frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                MangaArtView(style: manga.art)
            }
        }
    }

    private var placeholder: some View {
        let accents: [Accent] = [.moss, .clay, .blue, .yellow]
        let accent = accents[abs(manga.title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % accents.count]
        return ZStack {
            LinearGradient(colors: [accent.color, Theme.deep], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(manga.title.prefix(1)).uppercased())
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}
