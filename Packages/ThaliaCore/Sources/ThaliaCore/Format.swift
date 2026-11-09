import Foundation

/// German number formatting without depending on the device locale ("7,3", "2,5 l", "8.000",
/// "23:00", "1 h 20 min"). The tracker's content is German, so its numbers are too.
public enum Format {
    /// Up to `decimals` decimals, trailing zeros dropped, decimal comma, thousands dot: 150 → "150",
    /// 2.25 → "2,25", 8000 → "8.000".
    public static func number(_ value: Double, decimals: Int = 2) -> String {
        guard value.isFinite else { return "–" }
        let factor = pow(10, Double(decimals))
        let rounded = (value * factor).rounded() / factor
        let negative = rounded < 0
        let absolute = abs(rounded)
        let whole = Int(absolute)
        var fraction = Int(((absolute - Double(whole)) * factor).rounded())
        var integer = whole
        if fraction >= Int(factor) {
            integer += 1
            fraction -= Int(factor)
        }
        var text = grouped(integer)
        if decimals > 0, fraction > 0 {
            var digits = String(fraction)
            while digits.count < decimals { digits = "0" + digits }
            while digits.hasSuffix("0") { digits.removeLast() }
            text += "," + digits
        }
        return (negative && (integer > 0 || fraction > 0) ? "-" : "") + text
    }

    /// Always one decimal: 7.25 → "7,3", 10 → "10,0".
    /// Up to two decimals, no trailing zeros: "7,25", "8,5", "10" (v3).
    public static func score(_ value: Double) -> String {
        number(value, decimals: 2)
    }

    /// "7,25/10" or "–" when there is no score.
    public static func score(_ value: Double?, outOf: Bool = false) -> String {
        guard let value else { return "–" }
        return score(value) + (outOf ? "/10" : "")
    }

    /// The CSV form: dot decimal, no grouping ("2.5", "150").
    public static func plain(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int(value)) }
        var text = String(format: "%.4f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// Minutes since midnight → "23:00" (00:30 for 1470).
    public static func clock(_ minutes: Double) -> String {
        let total = ((Int(minutes.rounded()) % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// "50 min", "1 h 20 min", "2 h".
    public static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    /// Real hours: 1560 min → "26 h", 1525 → "25,4 h".
    public static func hours(minutes: Int) -> String {
        number(Double(minutes) / 60, decimals: 2) + " h"
    }

    /// Power-hours: 12 → "12 PH", 0.25 → "0,25 PH".
    public static func powerHours(_ value: Double) -> String {
        number(value, decimals: 2) + " PH"
    }

    /// A measured value with its unit: "150 g", "2,5 l", "23:10", "7,5 h".
    public static func measure(_ value: Double, unit: String) -> String {
        if Units.isTime(unit) { return clock(value) }
        let shown = Units.display(unit)
        let decimals = Units.normalized(unit) == "l" ? 2 : 1
        return shown.isEmpty ? number(value, decimals: decimals) : "\(number(value, decimals: decimals)) \(shown)"
    }

    /// Reads "2,5", "2.5", "1.200" (German thousands), "23:10" (as minutes when `isTime`).
    public static func parse(_ text: String, isTime: Bool = false) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if isTime || t.contains(":") {
            return Target.parseNumber(t).map(\.0)
        }
        var cleaned = t.replacingOccurrences(of: " ", with: "")
        // "1.200" (German thousands) vs "1.5" (decimal point).
        if cleaned.contains(","), cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else if cleaned.contains(",") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else if let dot = cleaned.firstIndex(of: "."), cleaned[cleaned.index(after: dot)...].count == 3, !cleaned.hasPrefix("0") {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
        }
        return Double(cleaned)
    }

    static func grouped(_ value: Int) -> String {
        let digits = String(value)
        guard digits.count > 3 else { return digits }
        var result = ""
        for (index, char) in digits.reversed().enumerated() {
            if index > 0, index % 3 == 0 { result.append(".") }
            result.append(char)
        }
        return String(result.reversed())
    }

    /// "1 Punkt" / "3 Punkte".
    public static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }
}
