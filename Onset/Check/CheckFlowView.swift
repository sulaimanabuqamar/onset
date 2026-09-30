import SwiftUI

/// Runs F → A → S (→ extra signs → T) and produces a CheckRecord.
struct CheckFlowView: View {
    let kind: CheckKind
    let profileID: UUID?
    var personName: String = "Unknown person"

    @EnvironmentObject private var store: OnsetStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .face
    @State private var face: FaceMeasurement?
    @State private var arm: ArmMeasurement?
    @State private var speech: SpeechMeasurement?
    @State private var other = OtherSigns()
    @State private var lastKnownWell: Date?
    @State private var lkwUnknown = false
    @State private var record: CheckRecord?
    @State private var startedAt = Date()

    enum Step: Int { case face, arm, speech, other, time, result, baselineSaved }

    private var profile: Profile? { store.profile(profileID) }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .face:
                    FaceStepView { m in face = m; go(.arm) }
                case .arm:
                    ArmStepView { m in arm = m; go(.speech) }
                case .speech:
                    SpeechStepView { m in speech = m; afterSpeech() }
                case .other:
                    OtherSignsStepView { s in other = s; go(.time) }
                case .time:
                    TimeStepView { date, unknown in
                        lastKnownWell = date
                        lkwUnknown = unknown
                        finish()
                    }
                case .result:
                    if let record { ResultView(record: record, profile: profile) { dismiss() } }
                case .baselineSaved:
                    BaselineSavedView(name: profile?.name ?? "") { dismiss() }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            .animation(.easeInOut(duration: 0.25), value: step)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Narrator.shared.stop(); dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .principal) {
                    if step.rawValue <= Step.time.rawValue {
                        ProgressDots(count: kind == .emergency ? 5 : 3, index: step.rawValue)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if kind == .emergency { CallNowPill() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(step != .result && step != .baselineSaved)
    }

    private func go(_ next: Step) {
        withAnimation { step = next }
    }

    private func afterSpeech() {
        if kind == .emergency { go(.other) } else { finish() }
    }

    private func finish() {
        Narrator.shared.stop()
        if kind == .baseline, let id = profileID {
            let fallbackFace = FaceMeasurement(smileAsymmetry: Grader.faceBorderline / 2, restAsymmetry: 0, leftSmile: 0.7, rightSmile: 0.7)
            let fallbackArm = ArmMeasurement(leftDrift: 4, rightDrift: 4, leftTremor: 0, rightTremor: 0)
            let fallbackSpeech = SpeechMeasurement(transcript: SpeechSentence.english, wordAccuracy: 1, clarity: 0.9, wordsPerSecond: 2.4)
            store.setBaseline(Baseline(recordedAt: Date(), face: face ?? fallbackFace, arm: arm ?? fallbackArm,
                                       speech: speech ?? fallbackSpeech), for: id)
            store.add(makeRecord(baseline: nil, findingsNormal: true))
            go(.baselineSaved)
            return
        }
        let r = makeRecord(baseline: profile?.baseline, findingsNormal: false)
        store.add(r)
        record = r
        go(.result)
    }

    private func makeRecord(baseline: Baseline?, findingsNormal: Bool) -> CheckRecord {
        CheckRecord(date: startedAt, kind: kind, profileID: profileID,
                    personName: profile?.name ?? personName,
                    face: face, arm: arm, speech: speech,
                    faceFinding: findingsNormal ? .normal : Grader.face(face, baseline: baseline),
                    armFinding: findingsNormal ? .normal : Grader.arm(arm, baseline: baseline),
                    speechFinding: findingsNormal ? .normal : Grader.speech(speech, baseline: baseline),
                    otherSigns: other, lastKnownWell: lastKnownWell, lastKnownWellUnknown: lkwUnknown)
    }
}

struct ProgressDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? Theme.red : Color(.tertiarySystemFill))
                    .frame(width: i == index ? 22 : 8, height: 8)
            }
        }
        .animation(.spring, value: index)
    }
}

struct BaselineSavedView: View {
    let name: String
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 90)).foregroundStyle(Theme.green)
            Text("\(name)'s normal is saved").font(.title.weight(.heavy)).multilineTextAlignment(.center)
            Text("From now on, every check compares against this face, these arms and this voice — not an average stranger's. That is what makes a small change visible.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
            PrimaryButton(title: "Done", action: onClose)
        }
        .padding()
        .onAppear { Haptics.success() }
    }
}
