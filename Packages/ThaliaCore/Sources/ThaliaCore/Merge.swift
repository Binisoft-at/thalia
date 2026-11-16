import Foundation

// Duplicates from offline sync (R28): two devices create the same day or week before they see each
// other's record. They are merged into one: "closed" wins, and filled-in text beats an empty newer
// version, so neither a day type nor a closing gets lost.

/// One stored version of a day.
public struct DayVersion: Equatable, Sendable {
    public var dayType: String
    public var note: String
    public var closedAt: Date?
    public var modifiedAt: Date

    public init(dayType: String, note: String, closedAt: Date?, modifiedAt: Date) {
        self.dayType = dayType
        self.note = note
        self.closedAt = closedAt
        self.modifiedAt = modifiedAt
    }
}

/// One stored version of a week.
public struct WeekVersion: Equatable, Sendable {
    public var title: String
    public var details: String
    public var recordedScore: Double?
    public var scoringModel: String
    public var closedAt: Date?
    public var importedAt: Date?
    public var finalScore: Double?
    public var finalGoalScores: String
    public var finalGoalsScored: Int
    public var modifiedAt: Date

    public init(title: String, details: String, recordedScore: Double?, scoringModel: String, closedAt: Date?, importedAt: Date?,
                finalScore: Double?, finalGoalScores: String, finalGoalsScored: Int, modifiedAt: Date) {
        self.title = title
        self.details = details
        self.recordedScore = recordedScore
        self.scoringModel = scoringModel
        self.closedAt = closedAt
        self.importedAt = importedAt
        self.finalScore = finalScore
        self.finalGoalScores = finalGoalScores
        self.finalGoalsScored = finalGoalsScored
        self.modifiedAt = modifiedAt
    }
}

public enum DuplicateMerge {
    /// Empty → nil. closedAt: the latest one set; dayType / note: from the newest version in which
    /// they aren't empty; modifiedAt: the latest.
    public static func day(_ versions: [DayVersion]) -> DayVersion? {
        let newestFirst = versions.sorted { $0.modifiedAt > $1.modifiedAt }
        guard let newest = newestFirst.first else { return nil }
        return DayVersion(
            dayType: newestFirst.first { !$0.dayType.isEmpty }?.dayType ?? "",
            note: newestFirst.first { !$0.note.isEmpty }?.note ?? "",
            closedAt: versions.compactMap(\.closedAt).max(),
            modifiedAt: newest.modifiedAt
        )
    }

    /// closedAt as for days; final*: from the newest closed version; title / details / recordedScore /
    /// importedAt: newest not empty; scoringModel: newest version; modifiedAt: the latest.
    public static func week(_ versions: [WeekVersion]) -> WeekVersion? {
        let newestFirst = versions.sorted { $0.modifiedAt > $1.modifiedAt }
        guard let newest = newestFirst.first else { return nil }
        let scored = newestFirst.first { $0.closedAt != nil } ?? newest
        return WeekVersion(
            title: newestFirst.first { !$0.title.isEmpty }?.title ?? "",
            details: newestFirst.first { !$0.details.isEmpty }?.details ?? "",
            recordedScore: newestFirst.first { $0.recordedScore != nil }?.recordedScore,
            scoringModel: newest.scoringModel,
            closedAt: versions.compactMap(\.closedAt).max(),
            importedAt: newestFirst.first { $0.importedAt != nil }?.importedAt,
            finalScore: scored.finalScore,
            finalGoalScores: scored.finalGoalScores,
            finalGoalsScored: scored.finalGoalsScored,
            modifiedAt: newest.modifiedAt
        )
    }
}
