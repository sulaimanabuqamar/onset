import SwiftUI

/// S — Speech. Repeat one sentence; the phone scores how much came through clearly.
struct SpeechStepView: View {
    let onDone: (SpeechMeasurement?) -> Void

    @StateObject private var tracker = SpeechTracker()
    @State private var phase: Phase = .ready
    @State private var result: SpeechMeasurement?
    @State private var remaining = 7.0

    enum Phase { case ready, listening, scoring, done }

    var body: some View {
        VStack(spacing: 18) {
            StepHeader(letter: "S", title: "Speech", subtitle: "Is speech slurred or strange?")

            Spacer(minLength: 0)

            Text("Say this sentence out loud:")
                .font(.headline).foregroundStyle(.secondary)
            Text("“\(SpeechSentence.english)”")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if phase == .listening || phase == .scoring || phase == .done {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Heard").font(.caption).foregroundStyle(.secondary)
                        Text(tracker.transcript.isEmpty && result == nil ? "…" : (result?.transcript ?? tracker.transcript))
                            .font(.title3)
                    }
                }
            }

            if phase == .listening {
                LevelBars(level: tracker.level)
                Text("\(Int(ceil(remaining)))s").font(.headline.monospacedDigit()).foregroundStyle(.secondary)
            }

            if phase == .done, let r = result {
                HStack(spacing: 14) {
                    Card {
                        VStack(alignment: .leading) {
                            Text("Words clear").font(.subheadline).foregroundStyle(.secondary)
                            Text("\(Int(r.wordAccuracy * 100))%").font(.title.weight(.bold))
                        }
                    }
                    Card {
                        VStack(alignment: .leading) {
                            Text("Pace").font(.subheadline).foregroundStyle(.secondary)
                            Text(String(format: "%.1f w/s", r.wordsPerSecond)).font(.title.weight(.bold))
                        }
                    }
                }
            }

            if tracker.permissionDenied {
                Text("Microphone or speech recognition is off. Listen yourself: are the words slurred, wrong, or missing?")
                    .font(.footnote).foregroundStyle(Theme.red).multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)

            switch phase {
            case .ready:
                PrimaryButton(title: "Start listening", systemImage: "mic.fill") { begin() }
                if tracker.permissionDenied {
                    HStack {
                        PrimaryButton(title: "Slurred", color: Theme.red) {
                            onDone(SpeechMeasurement(transcript: "(judged by ear)", wordAccuracy: 0.3, clarity: 0.3, wordsPerSecond: 0))
                        }
                        PrimaryButton(title: "Clear", color: Theme.green) {
                            onDone(SpeechMeasurement(transcript: "(judged by ear)", wordAccuracy: 1, clarity: 1, wordsPerSecond: 0))
                        }
                    }
                }
                Button("Skip speech test") { onDone(nil) }.foregroundStyle(.secondary).padding(.bottom, 8)
            case .listening:
                PrimaryButton(title: "Done speaking", systemImage: "stop.fill", color: Theme.ink) { stop() }
            case .scoring:
                ProgressView("Scoring…")
            case .done:
                HStack {
                    Button("Try again") { phase = .ready; result = nil }
                        .padding(.horizontal)
                    PrimaryButton(title: "Next", systemImage: "arrow.right") { onDone(result) }
                }
            }
        }
        .padding(.horizontal)
        .onAppear { Narrator.shared.say("Speech. Say: \(SpeechSentence.english).") }
        .onDisappear { tracker.cancel() }
    }

    private func begin() {
        Narrator.shared.stop()
        tracker.requestPermissions { ok in
            guard ok else { return }
            tracker.start()
            guard tracker.isListening else { return }
            phase = .listening
            Task { @MainActor in
                let start = Date()
                while phase == .listening && Date().timeIntervalSince(start) < 7 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    remaining = 7 - Date().timeIntervalSince(start)
                    let heard = SpeechTracker.normalize(tracker.transcript)
                    if heard.last == "tricks" && heard.count >= 5 {
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        break
                    }
                }
                if phase == .listening { stop() }
            }
        }
    }

    private func stop() {
        guard phase == .listening else { return }
        phase = .scoring
        tracker.finish { m in
            result = m
            phase = .done
            Haptics.success()
        }
    }
}

struct LevelBars: View {
    let level: Double
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<14, id: \.self) { i in
                let h = 10 + 50 * level * (0.5 + 0.5 * sin(Double(i) * 0.9))
                Capsule().fill(Theme.calm).frame(width: 7, height: max(8, h))
            }
        }
        .frame(height: 64)
        .animation(.easeOut(duration: 0.08), value: level)
    }
}
