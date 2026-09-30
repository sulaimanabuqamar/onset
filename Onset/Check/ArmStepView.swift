import SwiftUI

/// A — Arms. Each arm holds the phone out for 10 seconds with eyes closed.
struct ArmStepView: View {
    let onDone: (ArmMeasurement?) -> Void

    @StateObject private var tracker = ArmTracker()
    @State private var side: Side = .left
    @State private var phase: Phase = .instructions
    @State private var countdown = 3
    @State private var remaining = 10.0
    @State private var leftResult: (drift: Double, tremor: Double)?
    @State private var result: ArmMeasurement?

    enum Side { case left, right
        var name: String { self == .left ? "LEFT" : "RIGHT" }
    }
    enum Phase { case instructions, countdown, measuring, done }

    private let holdSeconds = 10.0

    var body: some View {
        VStack(spacing: 18) {
            StepHeader(letter: "A", title: "Arms", subtitle: "Does one arm drift down?")

            Spacer(minLength: 0)
            switch phase {
            case .instructions:
                instructions
            case .countdown:
                Text("\(countdown)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.red)
                Text("Put the phone flat on your \(side.name) palm").font(.title3.weight(.semibold))
            case .measuring:
                SpiritLevel(x: tracker.tiltX, y: tracker.tiltY, drift: tracker.currentDrift)
                Text("\(Int(ceil(remaining)))s")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("Eyes closed. Arm straight. Hold still.").foregroundStyle(.secondary)
            case .done:
                if let r = result { ArmSummary(m: r) }
            }
            Spacer(minLength: 0)

            switch phase {
            case .instructions:
                PrimaryButton(title: "Start \(side == .left ? "left" : "right") arm", systemImage: "hand.raised.fill") {
                    Task { await measure() }
                }
                Button("Skip arm test") { finish(skip: true) }.foregroundStyle(.secondary).padding(.bottom, 8)
            case .done:
                PrimaryButton(title: "Next: Speech", systemImage: "arrow.right") { onDone(result) }
            default:
                EmptyView()
            }
        }
        .padding(.horizontal)
        .onAppear {
            tracker.startPreview()
            Narrator.shared.say("Arms. You will hold the phone flat on your palm, arm straight out, eyes closed, for ten seconds.")
        }
        .onDisappear { tracker.stop() }
    }

    private var instructions: some View {
        VStack(spacing: 18) {
            Image(systemName: side == .left ? "hand.raised.fill" : "hand.raised.fill")
                .font(.system(size: 96))
                .foregroundStyle(Theme.calm)
                .scaleEffect(x: side == .left ? -1 : 1, y: 1)
            Text("\(side.name) arm")
                .font(.largeTitle.weight(.heavy))
            VStack(alignment: .leading, spacing: 10) {
                Label("Screen facing up, phone flat on the palm", systemImage: "iphone")
                Label("Arm straight out in front, at shoulder height", systemImage: "arrow.forward")
                Label("Close your eyes for 10 seconds", systemImage: "eye.slash")
                Label("The phone speaks when it's done", systemImage: "speaker.wave.2")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func measure() async {
        phase = .countdown
        Narrator.shared.say("\(side == .left ? "Left" : "Right") arm. Palm up, arm straight out.")
        for n in stride(from: 3, through: 1, by: -1) {
            countdown = n
            Haptics.tick()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        Narrator.shared.say("Close your eyes and hold still.")
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        tracker.beginMeasuring()
        phase = .measuring
        remaining = holdSeconds
        let start = Date()
        while Date().timeIntervalSince(start) < holdSeconds {
            try? await Task.sleep(nanoseconds: 100_000_000)
            remaining = holdSeconds - Date().timeIntervalSince(start)
        }
        let r = tracker.endMeasuring()
        Haptics.success()

        if side == .left {
            leftResult = r
            Narrator.shared.say("Done. Now the right arm.")
            side = .right
            phase = .instructions
        } else if let l = leftResult {
            Narrator.shared.say("Done. Open your eyes.")
            result = ArmMeasurement(leftDrift: l.drift, rightDrift: r.drift, leftTremor: l.tremor, rightTremor: r.tremor)
            phase = .done
        }
    }

    private func finish(skip: Bool) {
        Narrator.shared.stop()
        onDone(skip ? nil : result)
    }
}

struct SpiritLevel: View {
    let x: Double
    let y: Double
    let drift: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color(.tertiaryLabel), lineWidth: 2).frame(width: 220, height: 220)
            Circle().stroke(Theme.green.opacity(0.5), lineWidth: 2).frame(width: 70, height: 70)
            Circle()
                .fill(drift > Grader.armBorderline ? Theme.red : Theme.calm)
                .frame(width: 44, height: 44)
                .offset(x: CGFloat(max(-1, min(1, x))) * 110, y: CGFloat(max(-1, min(1, -y))) * 110)
                .animation(.easeOut(duration: 0.1), value: x)
            Text(String(format: "%.0f°", drift))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .offset(y: 130)
        }
        .frame(height: 260)
    }
}

struct ArmSummary: View {
    let m: ArmMeasurement
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                driftTile("Left arm", m.leftDrift)
                driftTile("Right arm", m.rightDrift)
            }
            Text("Drift = how far the phone tilted away from where the arm started.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
    private func driftTile(_ title: String, _ v: Double) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Text(String(format: "%.1f°", v)).font(.title.weight(.bold)).monospacedDigit()
                    .foregroundStyle(v >= Grader.armAbnormal ? Theme.red : (v >= Grader.armBorderline ? Theme.amber : .primary))
            }
        }
    }
}
