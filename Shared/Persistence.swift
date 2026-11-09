import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

/// Opens Thalia's store (rules in BinisoftKit `ModelStore`): synced through
/// `.private(APP_CLOUDKIT_CONTAINER)` with `groupContainer: .none`, Apple Health values in a
/// device-only store, local-only when iCloud isn't available, sample data in memory for `-Demo`,
/// and a separate practice store for the tour.
enum Persistence {
    static let models: [any PersistentModel.Type] = [
        AnnualGoal.self, TrackCategory.self, WeekPlan.self, PlanDay.self, PlanItem.self, MeasureDefinition.self,
        ItemMark.self, MeasureEntry.self, WorkBlock.self, DayNote.self, Reflection.self, ScoreOverride.self, AppSetting.self,
        WeekArchive.self, PlanChange.self,
    ]

    /// Never synced (App Store guideline 5.1.3(ii)).
    static let deviceOnlyModels: [any PersistentModel.Type] = [HealthValue.self]

    #if DEBUG
    static let isDebugBuild = true
    #else
    static let isDebugBuild = false
    #endif

    /// One container per process: the app, its intents and its widgets refresh share it.
    @MainActor
    static let shared: ModelStore.Opened = ModelStore.open(
        name: AppInfo.name,
        models: models,
        deviceOnlyModels: deviceOnlyModels,
        initializeCloudKitSchema: isDebugBuild,
        seedDemo: DemoData.seed
    )

    /// The tour's practice page: in memory, seeded with this week, never synced, gone when the tour closes.
    @MainActor
    static func practiceStore() -> ModelContainer {
        ModelStore.inMemory(name: "\(AppInfo.name)Tour", models: models + deviceOnlyModels, seed: DemoData.seedPractice)
    }
}
