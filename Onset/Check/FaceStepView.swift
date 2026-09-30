import SwiftUI

/// F — Face. Relax for 2 seconds, then a big smile for 3 seconds.
struct FaceStepView: View {
    let onDone: (FaceMeasurement?) -> Void

    @StateObject private var tracker = FaceTracker()
    @State private var phase: Phase = .findFace
    @State private var progress: Double = 0
    @State private var measurement: FaceMeasurement?

    enum Phase { case findFace, rest, smile, done, unsupported }

    var body: some View {
        VStack(spacing: 18) {
            StepHeader(letter: "F", title: "Face", subtitle: "Is one side of the face drooping?")

            ZStack {
                if FaceTracker.isSupported {
                    FaceMeshView(tracker: tracker)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 28).fill(Color(.tertiarySystemFill))
                }
                VStack {
                    Spacer()
                    prompt
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .padding(12)
                }
                if phase == .findFace && FaceTracker.isSupported && !tracker.faceVisible {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 140, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxHeight: 440)

            if phase == .rest || phase == .smile {
                SymmetryMeter(left: tracker.latest.smileLeft, right: tracker.latest.smileRight)
                ProgressView(value: progress).tint(Theme.calm)
            }

            if phase == .done, let m = measurement {
                FaceSummary(m: m)
            }

            Spacer(minLength: 0)
            bottomButtons
        }
        .padding(.horizontal)
        .onAppear {
            if FaceTracker.isSupported {
                tracker.start()
                Narrator.shared.say("Face. Look at the phone and relax your face.")
            } else {
                phase = .unsupported
            }
        }
        .onDisappear { tracker.stop() }
        .onChange(of: tracker.faceVisible) { _, visible in
            if visible && phase == .findFace { Task { await run() } }
        }
    }

    @ViewBuilder private var prompt: some View {
        switch phase {
        case .findFace:
            Label("Hold the phone at eye level, face in the frame", systemImage: "face.dashed")
        case .rest:
            Label("Relax your face… keep still", systemImage: "face.smiling")
        case .smile:
            Label("Now smile BIG — show your teeth!", systemImage: "mouth")
                .font(.title3.weight(.bold))
        case .done:
            Label("Face measured", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.green)
        case .unsupported:
            Text("This iPhone has no TrueDepth camera. Ask them to smile and look: does one side of the mouth droop?")
        }
    }

    @ViewBuilder private var bottomButtons: some View {
        switch phase {
        case .done:
            PrimaryButton(title: "Next: Arms", systemImage: "arrow.right") { onDone(measurement) }
        case .unsupported:
            HStack {
                PrimaryButton(title: "Face looks uneven", color: Theme.red) {
                    onDone(FaceMeasurement(smileAsymmetry: 1, restAsymmetry: 1, leftSmile: 0, rightSmile: 1))
                }
                PrimaryButton(title: "Looks even", color: Theme.green) {
                    onDone(FaceMeasurement(smileAsymmetry: 0, restAsymmetry: 0, leftSmile: 1, rightSmile: 1))
                }
            }
        default:
            Button("Skip face test") { onDone(nil) }
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
    }

    @MainActor
    private func run() async {
        phase = .rest
        Haptics.tick()
        tracker.beginRecording()
        await tick(seconds: 2)
        let rest = tracker.endRecording()

        phase = .smile
        Narrator.shared.say("Now smile big. Show your teeth.")
        Haptics.tick()
        try? await Task.sleep(nanoseconds: 700_000_000)
        tracker.beginRecording()
        await tick(seconds: 2.6)
        let smile = tracker.endRecording()

        measurement = FaceTracker.measure(rest: rest, smile: smile)
        phase = .done
        Haptics.success()
    }

    @MainActor
    private func tick(seconds: Double) async {
        progress = 0
        let steps = 30
        for i in 1...steps {
            try? await Task.sleep(nanoseconds: UInt64(seconds / Double(steps) * 1_000_000_000))
            progress = Double(i) / Double(steps)
        }
    }
}

struct SymmetryMeter: View {
    let left: Double
    let right: Double
    var body: some View {
        HStack(spacing: 12) {
            bar(left, label: "One side")
            Image(systemName: "arrow.left.and.right").foregroundStyle(.secondary)
            bar(right, label: "Other side")
        }
    }
    private func bar(_ v: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(Theme.calm).frame(width: g.size.width * min(1, max(0.02, v)))
                }
            }
            .frame(height: 10)
        }
    }
}

struct FaceSummary: View {
    let m: FaceMeasurement
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Smile symmetry").font(.subheadline).foregroundStyle(.secondary)
                Text("\(Int((1 - m.smileAsymmetry) * 100))% even").font(.title2.weight(.bold))
            }
            Spacer()
            SymmetryMeter(left: m.leftSmile, right: m.rightSmile).frame(width: 170)
        }
    }
}

struct StepHeader: View {
    let letter: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 14) {
            Text(letter)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Theme.red, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.bold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 6)
    }
}
