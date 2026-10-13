import SwiftUI
import UIKit

/// The profile photo as a circle, or the first letter of the name until one is chosen.
struct AvatarView: View {
    var data: Data?
    var name: String
    var size: CGFloat = 120

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.moss.opacity(0.16)
                    if let first = name.trimmingCharacters(in: .whitespaces).first {
                        Text(String(first).uppercased())
                            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.moss)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(Theme.moss)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
        .accessibilityLabel("Profile photo")
    }
}

enum AvatarImage {
    /// Shrinks a picked photo to a square-ish 400 px JPEG so it syncs quickly.
    static func prepare(_ raw: Data) -> Data? {
        guard let image = UIImage(data: raw) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 400 / longest)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: target).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
