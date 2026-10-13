import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var tint: Color = Theme.moss

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: progress)
        }
    }
}

struct ProgressBar: View {
    var progress: Double
    var tint: Color = Theme.moss
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.16))
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, proxy.size.width * min(max(progress, 0), 1)))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}

struct SectionHeader: View {
    var title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.title(20))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct IconBadge: View {
    var systemName: String
    var accent: Accent
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(accent.color)
            .frame(width: size, height: size)
            .background(accent.soft, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .accessibilityElement(children: .combine)
    }
}

/// Small pill used for tags and status labels.
struct TagPill: View {
    var text: String
    var accent: Accent

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(accent.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accent.soft, in: Capsule())
    }
}
