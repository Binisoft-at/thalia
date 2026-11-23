import Foundation
import BinisoftKitCore

/// German wording for the sync status (R79). The kit's texts are English and the kit stays
/// unchanged, so Thalia translates its states here (testable on Linux).
public enum SyncGerman {
    /// Where this launch keeps its data.
    public static func storage(_ mode: StorageMode) -> String {
        switch mode {
        case .iCloud: "Auf diesem Gerät + iCloud"
        case .local: "Nur auf diesem Gerät"
        case .memory: "Vorübergehend (nicht gesichert)"
        case .demo: "Beispieldaten (nicht gesichert)"
        }
    }

    /// The iCloud account as CloudKit reports it.
    public static func account(_ account: ICloudAccount) -> String {
        switch account {
        case .unknown: "Wird geprüft …"
        case .available: "Angemeldet"
        case .noAccount: "Nicht angemeldet"
        case .restricted: "Eingeschränkt"
        case .temporarilyUnavailable: "Vorübergehend nicht verfügbar"
        case .couldNotDetermine: "Unbekannt"
        }
    }

    /// One line for Settings: "An · zuletzt vor 5 Minuten", "Synchronisiert …", "Aus – in iCloud anmelden" …
    /// - Parameter relative: formats the last sync ("vor 5 Minuten").
    public static func summary(_ state: SyncState, relative: (Date) -> String) -> String {
        switch state.mode {
        case .memory: return "Aus – Daten können nicht gesichert werden"
        case .demo: return "Aus – Beispieldaten"
        case .local: return "Aus – nur dieses Gerät"
        case .iCloud:
            if state.account == .noAccount { return "Aus – in iCloud anmelden" }
            if state.account == .restricted { return "Aus – iCloud ist eingeschränkt" }
            if state.lastError != nil { return "Synchronisiert gerade nicht" }
            if state.isSyncing { return "Synchronisiert …" }
            if let lastSync = state.lastSync { return "An · zuletzt \(relative(lastSync))" }
            return "An"
        }
    }

    /// The sync error in German. `raw` is `SyncState.lastError`: either the kit's English sentence
    /// (`SyncErrorText.describe`) or the short raw error – both are recognised.
    public static func error(_ raw: String, appName: String) -> String {
        let lowered = raw.lowercased()
        func has(_ parts: String...) -> Bool { parts.contains { lowered.contains($0) } }
        if has("schema", "cannot create or modify field", "did not find record type", "unknown item") {
            return "iCloud kennt die Daten von \(appName) noch nicht (das CloudKit-Schema ist noch nicht freigegeben). Deine Daten sind auf diesem Gerät sicher und werden danach abgeglichen."
        }
        if has("quota", "storage is full") {
            return "Dein iCloud-Speicher ist voll. \(appName) gleicht wieder ab, sobald Platz ist."
        }
        if has("not authenticated", "notauthenticated", "no account", "sign in to icloud") {
            return "Melde dich in den Einstellungen bei iCloud an, damit abgeglichen wird."
        }
        if has("network", "offline", "internet") {
            return "Kein Netz – \(appName) gleicht ab, sobald du wieder online bist."
        }
        if (lowered.contains("zone") && lowered.contains("not found")) || lowered.contains("setting up") {
            return "iCloud richtet den Speicher für \(appName) ein. Das erledigt sich beim nächsten Abgleich."
        }
        return "iCloud meldet: \(raw)"
    }

    /// A state worth a line on the main screen (v11 P4.18): only lasting ones – the store couldn't be opened
    /// (`.memory`), iCloud is off (`.local`), no iCloud account, iCloud storage full. Never the demo, a short
    /// network error or an account still being checked at launch (`.unknown`, `.temporarilyUnavailable`,
    /// `.couldNotDetermine`).
    public static func isPersistentProblem(mode: StorageMode, account: ICloudAccount, quotaExceeded: Bool) -> Bool {
        switch mode {
        case .demo: return false
        case .memory, .local: return true
        case .iCloud: return account == .noAccount || quotaExceeded
        }
    }

    /// Why the data stays on this device, in German (the kit's reason is English); nil for iCloud and demo.
    public static func reason(_ mode: StorageMode) -> String? {
        switch mode {
        case .iCloud, .demo:
            return nil
        case .local(let reason):
            let lowered = (reason ?? "").lowercased()
            if lowered.contains("no icloud container") || lowered.contains("appcloudkitcontainer") {
                return "Kein iCloud-Container eingerichtet – deine Daten bleiben auf diesem Gerät."
            }
            return "iCloud-Speicher ließ sich nicht öffnen – deine Daten bleiben auf diesem Gerät."
        case .memory:
            return "Der Speicher auf diesem Gerät ließ sich nicht öffnen – Änderungen werden nicht gesichert."
        }
    }
}
