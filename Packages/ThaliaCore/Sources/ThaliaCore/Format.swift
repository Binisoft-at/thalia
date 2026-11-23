import Foundation

/// German number formatting without depending on the device locale ("7,3", "2,5 l", "8.000",
/// "23:00", "1 h 20 min"). The tracker's content is German, so its numbers are too.
public enum Format {
    /// Up to `decimals` decimals, trailing zeros dropped, decimal comma, thousands dot: 150 → "150",
    /// 2.25 → "2,25", 8000 → "8.000".
    /// "–" for a value that isn't finite or is too large to show (v11 P1.1 – `Int(Double)` trapped).
    public static func number(_ value: Double, decimals: Int = 2) -> String {
        guard value.isFinite, abs(value) < 1e15 else { return "–" }
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

    /// Minutes since midnight → "23:00" (00:30 for 1470); "–" when it isn't a time (v11 P1.1).
    public static func clock(_ minutes: Double) -> String {
        guard minutes.isFinite, abs(minutes) < 1e15 else { return "–" }
        let total = ((Int(minutes.rounded()) % 1440) + 1440) % 1440
        return pad(total / 60, 2) + ":" + pad(total % 60, 2)
    }

    /// "50 min", "1 h 20 min", "2 h"; "–" when too large to show (v11 P1.1).
    public static func duration(minutes: Int) -> String {
        guard abs(Double(minutes)) < 1e15 else { return "–" }
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

    /// To the cent (R17): 12.99 → "12,99 €", 2.5 → "2,50 €", 13 → "13 €", 1234.5 → "1.234,50 €",
    /// -3.5 → "-3,50 €".
    public static func euro(_ value: Double) -> String {
        guard value.isFinite, abs(value) < 1e15 else { return "– €" }
        let cents = Int((abs(value) * 100).rounded())
        let negative = value < 0 && cents > 0
        var text = grouped(cents / 100)
        if cents % 100 > 0 { text += "," + pad(cents % 100, 2) }
        return (negative ? "-" : "") + text + " €"
    }

    /// A measured value with its unit, rounded to `Units.decimals` (v11 P1.6): "150 g", "2,5 l", "23:10",
    /// "7,5 h", "0,25 PH", "12,99 €".
    public static func measure(_ value: Double, unit: String) -> String {
        if Units.isTime(unit) { return clock(value) }
        if Units.normalized(unit) == "€" { return euro(value) }
        let shown = Units.display(unit)
        let decimals = Units.decimals(unit)
        return shown.isEmpty ? number(value, decimals: decimals) : "\(number(value, decimals: decimals)) \(shown)"
    }

    /// A number as screens show it next to its unit (v11 P1.7), without the unit: rounded to
    /// `Units.decimals` – "86" (Stk.), "12,75" (PH), "7,5" (h), "23:00" (Uhrzeit); € to the cent like `euro`,
    /// without the sign ("32,50", "50"). For "6 von 8 PH" the caller adds the unit as before.
    public static func amount(_ value: Double, unit: String) -> String {
        if Units.isTime(unit) { return clock(value) }
        if Units.normalized(unit) == "€" {
            let text = euro(value)
            return text.hasSuffix(" €") ? String(text.dropLast(2)) : text
        }
        return number(value, decimals: Units.decimals(unit))
    }

    /// A target as screens show it after "von" or "Ziel" (v11 P1.7, KR3-6), without the unit: rounded to
    /// `Units.decimals` in the direction of the comparison, so a shown value is reached exactly when the
    /// exact one is – "≥ 85,71 Stk." → "86" ("von" already says "at least"), "> 85,71" → "> 85", "150–180 g × 6/7" →
    /// "129–154", "= 2,5" → "= 3" (rounded), limits "≤ 6" / "< 50", times as `Target.label` ("≤ 23:00",
    /// night windows "23:00–00:30"). Only the display: `Measures.effectiveTarget` and every score stay exact.
    public static func amount(target: Target, unit: String) -> String {
        if target.isTime || Units.isTime(unit) { return target.label }
        let decimals = Units.normalized(unit) == "€" ? 2 : Units.decimals(unit)
        func shown(_ value: Double, _ rounding: FloatingPointRoundingRule?) -> String {
            let factor = pow(10, Double(decimals))
            var rounded = value
            if value.isFinite, abs(value) < 1e12, let rounding {
                // A hair of tolerance, so 8 × 0,75 = 6,000000000001 stays 6.
                let scaled = value * factor
                let nudged = rounding == .up ? scaled - 1e-6 : scaled + 1e-6
                rounded = nudged.rounded(rounding) / factor
            }
            return amount(rounded, unit: unit)
        }
        switch target.comparison {
        case .atLeast: return shown(target.value, .up)
        case .above: return "> " + shown(target.value, .down)
        case .atMost: return "≤ " + shown(target.value, .down)
        case .below: return "< " + shown(target.value, .up)
        case .equal: return "= " + shown(target.value, nil)
        case .range: return shown(target.value, .up) + "–" + shown(target.upper ?? target.value, .down)
        }
    }

    /// Reads "2,5", "2.5", "1.200" (German thousands), "23:10" (as minutes when `isTime`). Strict (v11 P1.1):
    /// only digits, "." "," "+" "-" (and spaces), finite and below 10¹² – "nan", "inf", "1e5", hex and huge
    /// numbers are nil, like any other unreadable text.
    public static func parse(_ text: String, isTime: Bool = false) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if isTime || t.contains(":") {
            return Target.parseNumber(t).map(\.0)
        }
        var cleaned = t.replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty, cleaned.unicodeScalars.allSatisfy({ "0123456789.,+-".unicodeScalars.contains($0) }) else { return nil }
        // "1.200" (German thousands) vs "1.5" (decimal point).
        if cleaned.contains(","), cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else if cleaned.contains(",") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else if let dot = cleaned.firstIndex(of: "."), cleaned[cleaned.index(after: dot)...].count == 3, !cleaned.hasPrefix("0") {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
        }
        guard let value = Double(cleaned), value.isFinite, abs(value) < 1e12 else { return nil }
        return value
    }

    /// "7" → "07" (`width` 2), "2026" → "2026" (`width` 4): digits padded with zeros, without
    /// `String(format:)` (v11 P1.5 – days and weeks are built for every row).
    static func pad(_ value: Int, _ width: Int) -> String {
        if value < 0 { return "-" + pad(-value, max(1, width - 1)) }
        let digits = String(value)
        return digits.count >= width ? digits : String(repeating: "0", count: width - digits.count) + digits
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
