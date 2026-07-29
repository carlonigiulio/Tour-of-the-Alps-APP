import Foundation

enum Format {
    /// "MON 20 APR" — the compact date stamp used on stage cards.
    static func stageDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Language.current.rawValue)
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter.string(from: date)
    }

    static func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Language.current.rawValue)
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// `birth_date` arrives as a raw `dd/MM/yyyy` string. Reformat it for display when it
    /// parses, and pass it through untouched when it doesn't.
    static func birthDate(_ raw: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "dd/MM/yyyy"
        guard let date = parser.date(from: raw) else { return raw }
        let output = DateFormatter()
        output.locale = Locale(identifier: Language.current.rawValue)
        output.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return output.string(from: date)
    }

    static func km(_ value: Double) -> String {
        value.rounded() == value
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    static func metres(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
