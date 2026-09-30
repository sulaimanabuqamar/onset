import Foundation
import SwiftUI
import UserNotifications

/// Everything stays on the device. No account, no server.
@MainActor
final class OnsetStore: ObservableObject {
    @Published var profiles: [Profile] = [] { didSet { save() } }
    @Published var records: [CheckRecord] = [] { didSet { save() } }
    @Published var onboarded: Bool = UserDefaults.standard.bool(forKey: "onboarded") {
        didSet { UserDefaults.standard.set(onboarded, forKey: "onboarded") }
    }

    private struct Snapshot: Codable {
        var profiles: [Profile]
        var records: [CheckRecord]
    }

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("onset-data.json")
    }()

    private var loading = false

    init() { load() }

    // MARK: Persistence

    private func load() {
        loading = true
        defer { loading = false }
        guard let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        profiles = snap.profiles
        records = snap.records
    }

    private func save() {
        guard !loading else { return }
        let snap = Snapshot(profiles: profiles, records: records)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: url, options: [.atomic, .completeFileProtection])
        }
    }

    // MARK: Profiles

    func profile(_ id: UUID?) -> Profile? {
        guard let id else { return nil }
        return profiles.first { $0.id == id }
    }

    func upsert(_ profile: Profile) {
        if let i = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[i] = profile
        } else {
            profiles.append(profile)
        }
    }

    func delete(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        records.removeAll { $0.profileID == profile.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [profile.id.uuidString])
    }

    func setBaseline(_ baseline: Baseline, for id: UUID) {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[i].baseline = baseline
    }

    func history(for id: UUID) -> [CheckRecord] {
        records.filter { $0.profileID == id }.sorted { $0.date < $1.date }
    }

    func add(_ record: CheckRecord) {
        records.append(record)
    }

    // MARK: Weekly check-in reminders (Family plan)

    func scheduleWeeklyCheckIn(for profile: Profile, weekday: Int, hour: Int = 10) {
        var updated = profile
        updated.checkInWeekday = weekday
        upsert(updated)

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Weekly check-in for \(profile.name)"
            content.body = "20 seconds: smile, hold out an arm, say one sentence. Onset compares it with their normal."
            content.sound = .default
            var date = DateComponents()
            date.weekday = weekday
            date.hour = hour
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: profile.id.uuidString, content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelWeeklyCheckIn(for profile: Profile) {
        var updated = profile
        updated.checkInWeekday = nil
        upsert(updated)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [profile.id.uuidString])
    }

    // MARK: Sample family (for demos and screenshots)

    func loadSampleFamily() {
        let now = Date()
        func base(_ smile: Double, _ l: Double, _ r: Double, _ acc: Double) -> Baseline {
            Baseline(recordedAt: now.addingTimeInterval(-60 * 60 * 24 * 63),
                     face: FaceMeasurement(smileAsymmetry: smile, restAsymmetry: smile * 0.6, leftSmile: 0.78, rightSmile: 0.78 * (1 - smile)),
                     arm: ArmMeasurement(leftDrift: l, rightDrift: r, leftTremor: 0.01, rightTremor: 0.01),
                     speech: SpeechMeasurement(transcript: SpeechSentence.english, wordAccuracy: acc, clarity: 0.9, wordsPerSecond: 2.4))
        }
        let mum = Profile(name: "Mama Leila", relation: "Mother", birthYear: 1961, takesBloodThinners: true,
                          medicalNotes: "Type 2 diabetes, high blood pressure. Takes apixaban.",
                          baseline: base(0.11, 3.2, 4.0, 1.0), checkInWeekday: 6)
        let dad = Profile(name: "Baba Omar", relation: "Father", birthYear: 1957, takesBloodThinners: false,
                          medicalNotes: "High blood pressure.", baseline: base(0.08, 2.6, 2.9, 1.0), checkInWeekday: 6)
        profiles.removeAll { $0.relation == "Mother" || $0.relation == "Father" }
        profiles.append(contentsOf: [mum, dad])

        var sample: [CheckRecord] = []
        for week in 0..<9 {
            let date = now.addingTimeInterval(-Double(8 - week) * 60 * 60 * 24 * 7)
            for p in [mum, dad] {
                let wobble = Double((week * 7 + p.name.count) % 5) * 0.012
                let face = FaceMeasurement(smileAsymmetry: (p.baseline?.face.smileAsymmetry ?? 0.1) + wobble,
                                           restAsymmetry: 0.06 + wobble / 2, leftSmile: 0.76, rightSmile: 0.7)
                let arm = ArmMeasurement(leftDrift: 3 + wobble * 20, rightDrift: 3.5 + wobble * 15, leftTremor: 0.01, rightTremor: 0.01)
                let speech = SpeechMeasurement(transcript: SpeechSentence.english, wordAccuracy: 1, clarity: 0.9, wordsPerSecond: 2.3)
                sample.append(CheckRecord(date: date, kind: .weekly, profileID: p.id, personName: p.name,
                                          face: face, arm: arm, speech: speech,
                                          faceFinding: .normal, armFinding: .normal, speechFinding: .normal,
                                          otherSigns: OtherSigns(), lastKnownWell: nil, lastKnownWellUnknown: false))
            }
        }
        records.append(contentsOf: sample)
    }
}
