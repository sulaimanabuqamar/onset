import Foundation

// MARK: - People

struct Profile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var relation: String            // "Me", "Mother", "Father"…
    var birthYear: Int?
    var takesBloodThinners: Bool = false
    var medicalNotes: String = ""
    var baseline: Baseline?
    var checkInWeekday: Int? = nil  // 1 = Sunday … 7 = Saturday (Pro weekly check-in)

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var age: Int? {
        guard let birthYear else { return nil }
        return Calendar.current.component(.year, from: Date()) - birthYear
    }
}

/// A person's own "normal". Faces, arms and voices are never perfectly symmetric,
/// so every later check is compared against this instead of a population average.
struct Baseline: Codable, Hashable {
    var recordedAt: Date
    var face: FaceMeasurement
    var arm: ArmMeasurement
    var speech: SpeechMeasurement
}

// MARK: - Measurements

struct FaceMeasurement: Codable, Hashable {
    /// 0 = perfectly even smile, 1 = one side does not move at all.
    var smileAsymmetry: Double
    /// Asymmetry with the face relaxed (drooping corner of the mouth).
    var restAsymmetry: Double
    var leftSmile: Double
    var rightSmile: Double

    /// The side that moves less (the side the person would call "their" left/right).
    var weakerSide: String { leftSmile < rightSmile ? "left" : "right" }
    /// True when there was no TrueDepth camera and the person judged the face by eye.
    var judgedByEye: Bool { leftSmile + rightSmile == 1 && (smileAsymmetry == 0 || smileAsymmetry == 1) }
}

struct ArmMeasurement: Codable, Hashable {
    /// Largest tilt (degrees) away from the starting position, per arm.
    var leftDrift: Double
    var rightDrift: Double
    var leftTremor: Double
    var rightTremor: Double

    var maxDrift: Double { max(leftDrift, rightDrift) }
    var difference: Double { abs(leftDrift - rightDrift) }
    var weakerSide: String { leftDrift > rightDrift ? "left" : "right" }
}

struct SpeechMeasurement: Codable, Hashable {
    var transcript: String
    /// Share of the target sentence recognised correctly (0…1).
    var wordAccuracy: Double
    /// Mean recogniser confidence (0…1), a proxy for clarity.
    var clarity: Double
    var wordsPerSecond: Double
}

// MARK: - Findings

enum Finding: String, Codable {
    case normal, borderline, abnormal, skipped

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .borderline: return "Watch"
        case .abnormal: return "Sign found"
        case .skipped: return "Skipped"
        }
    }
}

struct OtherSigns: Codable, Hashable {
    var balance = false     // sudden loss of balance / dizziness
    var eyes = false        // sudden vision loss / double vision
    var headache = false    // sudden severe headache
    var confusion = false   // sudden confusion / trouble understanding

    var any: Bool { balance || eyes || headache || confusion }

    var list: [String] {
        var out: [String] = []
        if balance { out.append("Sudden loss of balance") }
        if eyes { out.append("Sudden vision change") }
        if headache { out.append("Sudden severe headache") }
        if confusion { out.append("Sudden confusion") }
        return out
    }
}

enum CheckKind: String, Codable {
    case emergency, baseline, weekly
}

struct CheckRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var kind: CheckKind
    var profileID: UUID?
    var personName: String
    var face: FaceMeasurement?
    var arm: ArmMeasurement?
    var speech: SpeechMeasurement?
    var faceFinding: Finding
    var armFinding: Finding
    var speechFinding: Finding
    var otherSigns: OtherSigns
    var lastKnownWell: Date?
    var lastKnownWellUnknown: Bool

    var callNow: Bool {
        faceFinding == .abnormal || armFinding == .abnormal || speechFinding == .abnormal || otherSigns.any
    }

    var watch: Bool {
        !callNow && (faceFinding == .borderline || armFinding == .borderline || speechFinding == .borderline)
    }
}

// MARK: - Grading

enum Grader {
    // Thresholds used when the person has no baseline. Deliberately cautious:
    // a false alarm costs a phone call, a missed stroke costs brain.
    static let faceAbnormal = 0.30, faceBorderline = 0.20
    static let faceDeltaAbnormal = 0.18, faceDeltaBorderline = 0.10
    static let armAbnormal = 14.0, armBorderline = 9.0
    static let armDiffAbnormal = 9.0
    static let armDeltaAbnormal = 8.0, armDeltaBorderline = 5.0
    static let speechAbnormal = 0.60, speechBorderline = 0.80
    static let speechDeltaAbnormal = 0.30, speechDeltaBorderline = 0.15

    static func face(_ m: FaceMeasurement?, baseline: Baseline?) -> Finding {
        guard let m else { return .skipped }
        let score = max(m.smileAsymmetry, m.restAsymmetry)
        if let b = baseline {
            let base = max(b.face.smileAsymmetry, b.face.restAsymmetry)
            let delta = score - base
            if delta >= faceDeltaAbnormal { return .abnormal }
            if delta >= faceDeltaBorderline { return .borderline }
            return .normal
        }
        if score >= faceAbnormal { return .abnormal }
        if score >= faceBorderline { return .borderline }
        return .normal
    }

    static func arm(_ m: ArmMeasurement?, baseline: Baseline?) -> Finding {
        guard let m else { return .skipped }
        if let b = baseline {
            let delta = max(m.leftDrift - b.arm.leftDrift, m.rightDrift - b.arm.rightDrift)
            if delta >= armDeltaAbnormal || m.difference >= armDiffAbnormal + b.arm.difference { return .abnormal }
            if delta >= armDeltaBorderline { return .borderline }
            return .normal
        }
        if m.maxDrift >= armAbnormal || m.difference >= armDiffAbnormal { return .abnormal }
        if m.maxDrift >= armBorderline { return .borderline }
        return .normal
    }

    static func speech(_ m: SpeechMeasurement?, baseline: Baseline?) -> Finding {
        guard let m else { return .skipped }
        if let b = baseline {
            let delta = b.speech.wordAccuracy - m.wordAccuracy
            if delta >= speechDeltaAbnormal || m.wordAccuracy < speechAbnormal { return .abnormal }
            if delta >= speechDeltaBorderline { return .borderline }
            return .normal
        }
        if m.wordAccuracy < speechAbnormal { return .abnormal }
        if m.wordAccuracy < speechBorderline { return .borderline }
        return .normal
    }
}
