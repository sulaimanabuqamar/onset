import AVFoundation
import Speech
import SwiftUI

/// Listens to one repeated sentence and scores how much of it came through clearly.
/// Recognition runs on the device when the phone supports it.
final class SpeechTracker: ObservableObject {
    @Published var transcript = ""
    @Published var isListening = false
    @Published var level: Double = 0
    @Published var permissionDenied = false

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var startedAt: Date?
    private var lastResult: SFSpeechRecognitionResult?
    private var tapInstalled = false

    func requestPermissions(_ done: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioApplication.requestRecordPermission { mic in
                DispatchQueue.main.async {
                    let ok = status == .authorized && mic
                    self.permissionDenied = !ok
                    done(ok)
                }
            }
        }
    }

    func start() {
        guard let recognizer, recognizer.isAvailable else { permissionDenied = true; return }
        if tapInstalled || engine.isRunning { stopEngine() }
        transcript = ""
        lastResult = nil

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        request.contextualStrings = SpeechSentence.english.components(separatedBy: " ")
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // No usable microphone input (e.g. another app holds it): fall back to judging by ear.
        guard format.sampleRate > 0, format.channelCount > 0 else { permissionDenied = true; return }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            guard let channel = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<n { sum += channel[i] * channel[i] }
            let rms = n > 0 ? (sum / Float(n)).squareRoot() : 0
            DispatchQueue.main.async { self?.level = min(1, Double(rms) * 12) }
        }

        tapInstalled = true
        engine.prepare()
        do { try engine.start() } catch { permissionDenied = true; return }
        startedAt = Date()
        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            DispatchQueue.main.async {
                self.lastResult = result
                self.transcript = result.bestTranscription.formattedString
            }
        }
    }

    /// Stops listening and scores what was heard.
    func finish(_ done: @escaping (SpeechMeasurement) -> Void) {
        request?.endAudio()
        let elapsed = max(1, Date().timeIntervalSince(startedAt ?? Date()))
        // Give the recogniser a moment to deliver its final result.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.stopEngine()
            let text = self.lastResult?.bestTranscription.formattedString ?? self.transcript
            let segments = self.lastResult?.bestTranscription.segments ?? []
            let confidences = segments.map { Double($0.confidence) }.filter { $0 > 0 }
            let clarity = confidences.isEmpty ? 0.8 : confidences.average
            let accuracy = Self.wordAccuracy(heard: text, target: SpeechSentence.english)
            let words = Double(text.split(separator: " ").count)
            done(SpeechMeasurement(transcript: text, wordAccuracy: accuracy, clarity: clarity,
                                   wordsPerSecond: words / elapsed))
        }
    }

    func cancel() { stopEngine() }

    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Scoring

    static func normalize(_ s: String) -> [String] {
        s.lowercased()
            .replacingOccurrences(of: "can't", with: "cannot")
            .replacingOccurrences(of: "cant", with: "cannot")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// 1 − word error rate (Levenshtein distance over words), clamped to 0…1.
    static func wordAccuracy(heard: String, target: String) -> Double {
        let h = normalize(heard), t = normalize(target)
        guard !t.isEmpty else { return 0 }
        if h.isEmpty { return 0 }
        var prev = Array(0...h.count)
        for i in 1...t.count {
            var cur = [i] + Array(repeating: 0, count: h.count)
            for j in 1...h.count {
                let cost = t[i - 1] == h[j - 1] ? 0 : 1
                cur[j] = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            prev = cur
        }
        let wer = Double(prev[h.count]) / Double(t.count)
        return Swift.max(0, 1 - wer)
    }
}
