import SwiftUI
import UIKit

/// A poster-sized, self-contained snapshot of the current Dayforge pulse.
/// It is rendered locally so sharing does not need a network request or account data.
struct PulseArtifact: View {
    let pulse: Int
    let message: String
    let habitsDone: Int
    let habitsTotal: Int
    let focusMinutes: Int
    let nextMove: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.ink, Theme.deep, Theme.moss],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            abstractArtwork

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("DAYFORGE / DAILY PULSE")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Text(Date().formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                        .font(.system(size: 19, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer(minLength: 0)

                Text("A SMALL SIGNAL\nFOR A FULL DAY")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .tracking(2.8)
                    .foregroundStyle(Theme.yellow)
                    .lineSpacing(5)

                Text("\(pulse)")
                    .font(.system(size: 250, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .tracking(-10)
                    .padding(.top, 20)

                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Theme.yellow)
                        .frame(width: 70, height: 4)
                    Text("PULSE / 100")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.74))
                }
                .padding(.top, 2)

                Text(message)
                    .font(.system(size: 39, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 55)

                Text("Keep the next right move small.")
                    .font(.system(size: 21, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.top, 18)

                metrics
                    .padding(.top, 58)

                VStack(alignment: .leading, spacing: 9) {
                    Text("NEXT MOVE")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(Theme.yellow)
                    Text(nextMove.replacingOccurrences(of: "Next: ", with: ""))
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(.top, 48)

                Spacer(minLength: 0)

                HStack {
                    Text("FORGE THE DAY")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("DAYFORGE")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(78)
        }
        .preferredColorScheme(.light)
    }

    private var abstractArtwork: some View {
        ZStack {
            Circle()
                .fill(Theme.moss.opacity(0.54))
                .frame(width: 720, height: 720)
                .blur(radius: 4)
                .offset(x: 360, y: -470)
            Circle()
                .stroke(Theme.yellow.opacity(0.26), lineWidth: 3)
                .frame(width: 820, height: 820)
                .offset(x: 390, y: -420)
            Capsule()
                .fill(Theme.clay.opacity(0.18))
                .frame(width: 920, height: 260)
                .rotationEffect(.degrees(-28))
                .offset(x: -360, y: 520)
        }
        .ignoresSafeArea()
    }

    private var metrics: some View {
        HStack(spacing: 14) {
            shareMetric(value: "\(habitsDone)/\(habitsTotal)", label: "habits")
            shareMetric(value: "\(focusMinutes)", label: "focus min")
            shareMetric(value: nextMove.hasPrefix("Next:") ? "1" : "✓", label: "next move")
        }
    }

    private func shareMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PulseShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
