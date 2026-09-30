import Foundation

enum Config {
    /// RevenueCat public SDK key.
    /// This is the project's **Test Store** key: purchases run through RevenueCat's
    /// Test Store, so no App Store Connect account is needed to try the Family plan.
    /// Test Store keys only work in Debug builds (the SDK stops a Release build on purpose).
    static let revenueCatAPIKey = "test_aCPRtbEMBlmPXZdFktrYxldRWyC"
}

enum EmergencyNumber {
    /// Ambulance number for the phone's region.
    static var current: String {
        switch Locale.current.region?.identifier ?? "" {
        case "AE": return "998"
        case "SA": return "997"
        case "QA", "KW", "BH", "OM": return "999"
        case "EG": return "123"
        case "US", "CA": return "911"
        case "GB", "IE": return "999"
        case "AU": return "000"
        case "IN": return "108"
        default: return "112"   // Turkey, EU and many others
        }
    }

    static var url: URL? { URL(string: "tel://\(current)") }
}

enum SpeechSentence {
    /// From the Cincinnati Prehospital Stroke Scale.
    static let english = "You can't teach an old dog new tricks"
}
