import AVFoundation
import SwiftUI
import UIKit

enum Theme {
    static let red = Color(red: 0.90, green: 0.18, blue: 0.22)
    static let deepRed = Color(red: 0.62, green: 0.07, blue: 0.12)
    static let amber = Color(red: 0.96, green: 0.62, blue: 0.10)
    static let green = Color(red: 0.16, green: 0.66, blue: 0.43)
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.14)
    static let calm = Color(red: 0.22, green: 0.45, blue: 0.95)

    static func color(for finding: Finding) -> Color {
        switch finding {
        case .normal: return green
        case .borderline: return amber
        case .abnormal: return red
        case .skipped: return .secondary
        }
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = Theme.calm
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct CallNowPill: View {
    var body: some View {
        if let url = EmergencyNumber.url {
            Link(destination: url) {
                Label("Call \(EmergencyNumber.current)", systemImage: "phone.fill")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(Theme.red, in: Capsule())
            }
        }
    }
}

struct FindingBadge: View {
    let finding: Finding
    var body: some View {
        Text(finding.label)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(finding == .skipped ? Color.secondary : .white)
            .background(finding == .skipped ? Color(.tertiarySystemFill) : Theme.color(for: finding), in: Capsule())
    }
}

/// Spoken prompts, because in the arm test the person has their eyes closed
/// and in an emergency nobody wants to read.
final class Narrator {
    static let shared = Narrator()
    private let synth = AVSpeechSynthesizer()
    var enabled = true

    func say(_ text: String) {
        guard enabled else { return }
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.rate = 0.5
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(u)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }
}

enum Haptics {
    static func tick() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

extension Date {
    var clock: String { formatted(date: .omitted, time: .shortened) }
}

func durationString(_ interval: TimeInterval) -> String {
    let s = max(0, Int(interval))
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
}
