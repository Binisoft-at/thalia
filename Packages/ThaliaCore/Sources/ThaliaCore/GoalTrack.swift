import Foundation

// Weeks above 8 (TASKS-v10 §1.2.3): a category is "gut dabei" in a week when its week score, rounded to
// two places like on screen, is at least 8,00. A goal is "gut dabei" when every scored category of it
// is. Closed weeks keep their category scores in the setting `score.<week>` ("1.1=8.2;1.2=6.5"),
// written with the final score; archive weeks (v9) take them from their grades. Excused weeks don't count.

public enum GoalTrack {
    /// "über 8" – decided: counts from 8,00 (rounded to two places).
    public static let threshold = 8.0
    /// The badge on a category row and head.
    public static let badge = "✓ über 8"
    /// How many scored weeks the goal card counts back.
    public static let recentWeeks = 12

    /// "score." – the prefix of the stored category week scores.
    public static let settingPrefix = SettingKeys.categoryScores

    /// "score.2026-W47"
    public static func settingKey(_ week: WeekKey) -> String { settingPrefix + week.string }

    /// "score.2026-W47" → 2026-W47; nil for other keys.
    public static func week(settingKey key: String) -> WeekKey? {
        guard key.hasPrefix(settingPrefix) else { return nil }
        return WeekKey(String(key.dropFirst(settingPrefix.count)))
    }

    /// "1.1=8.2;1.2=6.5" – by category key, values as in the CSV (`Format.plain`).
    public static func text(_ scores: [String: Double]) -> String {
        scores.keys.sorted { CategoryRecord.sortKey($0).lexicographicallyPrecedes(CategoryRecord.sortKey($1)) }
            .compactMap { key in scores[key].flatMap { $0.isFinite ? "\(key)=\(Format.plain($0))" : nil } }
            .joined(separator: ";")
    }

    /// Reads "1.1=8.2;1.2=6.5" (also "1.1=8,2", spaces, a trailing ";"); unreadable parts are left out.
    public static func scores(_ text: String) -> [String: Double] {
        var result: [String: Double] = [:]
        for part in text.split(whereSeparator: { $0 == ";" || $0 == "\n" }) {
            let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard pair.count == 2, !pair[0].isEmpty, let value = Double(pair[1].replacingOccurrences(of: ",", with: ".")),
                  value.isFinite else { continue }
            result[pair[0]] = value
        }
        return result
    }

    /// Rounded to two places, as `Format.score` shows it.
    public static func rounded(_ value: Double) -> Double { (value * 100).rounded() / 100 }

    /// The score counts as "über 8": rounded to two places ≥ 8,00 – the same rounding as on screen, so a
    /// shown "8" always counts and a shown "7,99" never does (7,994 doesn't, 7,996 does).
    public static func isGood(_ score: Double?) -> Bool {
        guard let score, score.isFinite else { return false }
        return rounded(score) >= threshold - 1e-9
    }

    /// A goal is "gut dabei" when every scored category of it is; nil when none of them is scored.
    public static func goalIsGood(_ goalKey: String, categories: [CategoryRecord], scores: [String: Double]) -> Bool? {
        let scored = categories.filter { $0.goalKey == goalKey }.compactMap { scores[$0.key] }
        guard !scored.isEmpty else { return nil }
        return scored.allSatisfy { isGood($0) }
    }

    /// One week's category scores.
    public struct Week: Equatable, Sendable {
        public var week: WeekKey
        /// Category key → week score (0…10).
        public var scores: [String: Double]
        /// A fully excused week (sick or on holiday): it doesn't count.
        public var isExcused: Bool

        public init(week: WeekKey, scores: [String: Double], isExcused: Bool = false) {
            self.week = week
            self.scores = scores
            self.isExcused = isExcused
        }

        /// From a stored setting value ("1.1=8.2;1.2=6.5").
        public init(week: WeekKey, text: String, isExcused: Bool = false) {
            self.init(week: week, scores: GoalTrack.scores(text), isExcused: isExcused)
        }
    }

    /// "1.1 9/12": weeks above 8 of the weeks the category was scored in.
    public struct Tally: Equatable, Sendable {
        public var key: String
        public var good: Int
        public var scored: Int

        public init(key: String, good: Int, scored: Int) {
            self.key = key
            self.good = good
            self.scored = scored
        }

        /// "1.1 9/12"
        public var text: String { "\(key) \(good)/\(scored)" }
    }

    /// Per category: of its last `limit` scored weeks (in `range`, e.g. the current segment's weeks),
    /// how many were above 8. Excused weeks and weeks without a score of the category don't count.
    /// Categories without any scored week are left out.
    public static func tallies(_ weeks: [Week], categories: [String], limit: Int? = recentWeeks,
                               range: ClosedRange<WeekKey>? = nil) -> [Tally] {
        let counted = weeks.filter { !$0.isExcused && (range?.contains($0.week) ?? true) }.sorted { $0.week < $1.week }
        return categories.compactMap { key in
            var values = counted.compactMap { $0.scores[key] }
            if let limit, values.count > limit { values = Array(values.suffix(limit)) }
            guard !values.isEmpty else { return nil }
            return Tally(key: key, good: values.filter { isGood($0) }.count, scored: values.count)
        }
    }

    /// "Wochen über 8: 1.1 9/12 · 1.2 7/12"; nil without any scored week.
    public static func line(_ tallies: [Tally]) -> String? {
        guard !tallies.isEmpty else { return nil }
        return "Wochen über 8: " + tallies.map(\.text).joined(separator: " · ")
    }

    /// All category weeks above 8 in `range` ("Kategorie-Wochen über 8" of an earlier segment):
    /// (above 8, scored) over every category in `categories` (all when nil).
    public static func total(_ weeks: [Week], categories: [String]? = nil, range: ClosedRange<WeekKey>? = nil) -> (good: Int, scored: Int) {
        var good = 0
        var scored = 0
        for week in weeks where !week.isExcused && (range?.contains(week.week) ?? true) {
            for (key, value) in week.scores where categories?.contains(key) ?? true {
                scored += 1
                if isGood(value) { good += 1 }
            }
        }
        return (good, scored)
    }

    /// The weeks a goal was "gut dabei" in, of those where any of its categories was scored.
    public static func goalWeeks(_ goalKey: String, weeks: [Week], categories: [CategoryRecord],
                                 range: ClosedRange<WeekKey>? = nil) -> (good: Int, scored: Int) {
        var good = 0
        var scored = 0
        for week in weeks where !week.isExcused && (range?.contains(week.week) ?? true) {
            guard let value = goalIsGood(goalKey, categories: categories, scores: week.scores) else { continue }
            scored += 1
            if value { good += 1 }
        }
        return (good, scored)
    }

    /// The category scores of a scored week to store: `WeekScore.categoryWeek` – nothing for a fully
    /// excused week.
    public static func scores(of score: WeekScore) -> [String: Double] {
        score.isExcused ? [:] : score.categoryWeek
    }

    /// The category scores of an archive week (v9): its grades under today's rules (mapped categories only).
    public static func scores(of archive: ArchiveRecalculation) -> [String: Double] {
        archive.categories
    }
}
