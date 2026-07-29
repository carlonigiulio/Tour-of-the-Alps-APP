import Foundation

/// Build-config driven settings. The API base URL comes from the `TOTA_API_BASE_URL`
/// build setting, injected into Info.plist as `TOTAAPIBaseURL`, so pointing the app at
/// a real host later is a build-setting change rather than a code change.
enum AppConfig {
    static let apiBaseURL: URL = {
        let fallback = URL(string: "http://localhost:8088/api/v1")!
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "TOTAAPIBaseURL") as? String,
              !raw.isEmpty,
              let url = URL(string: raw)
        else { return fallback }
        return url
    }()
}

/// The three languages the API serves. Driven by the device locale, falling back to `en`.
enum Language: String, CaseIterable, Sendable {
    case en, it, de

    static var current: Language {
        let code = Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier }
        return code.flatMap(Language.init(rawValue:)) ?? .en
    }
}
