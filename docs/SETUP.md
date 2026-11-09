# Thalia – setup

The account steps for this app, from the Binisoft handbook's
[SETUP_CHECKLIST.md](https://github.com/Binisoft-at/binisoft-handbook/blob/main/SETUP_CHECKLIST.md)
with Thalia's values. Claude turns it into a numbered claude.ai checklist and ticks steps off.

| | |
|---|---|
| App Store name | **Thalia - Your Tracker Buddy** |
| Home-screen name | Thalia |
| GitHub repo | `Binisoft-at/thalia` (private) |
| Bundle ID (iOS + macOS) = SKU | `at.binisoft.thalia` |
| Watch app | `at.binisoft.thalia.watchkitapp` (ships inside the iOS app) |
| Widgets | `at.binisoft.thalia.widgets` |
| Own iCloud container | `iCloud.at.binisoft.thalia` |
| Shared iCloud container / App Group | `iCloud.at.binisoft.shared` / `group.at.binisoft.shared` (exist – only tick them) |
| Shared keychain group | `$(AppIdentifierPrefix)at.binisoft.shared` (no portal step) |
| TestFlight group | `Binisoft Team`, automatic distribution |
| Extra capability | **HealthKit** on `at.binisoft.thalia` only (read-only suggestions; values stay on the device) |
| No portal step | local notifications, Live Activity (widget extension), App Shortcuts, URL scheme `thalia://` |

All identifiers are defined in [`Config/Base.xcconfig`](../Config/Base.xcconfig).

## Steps (short form)

1. **GitHub** – private repo `Binisoft-at/thalia`, attached to the session.
2. **Portal** – iCloud container `iCloud.at.binisoft.thalia`; App IDs `at.binisoft.thalia`
   (App Groups, iCloud with CloudKit, Push Notifications, **HealthKit**; groups/containers configured),
   `at.binisoft.thalia.watchkitapp` (same), `at.binisoft.thalia.widgets` (App Groups).
3. **App Store Connect** – New App (iOS + macOS) "Thalia - Your Tracker Buddy", bundle ID and SKU
   `at.binisoft.thalia`; TestFlight → Internal Testing → `Binisoft Team`, automatic distribution.
4. **Repository secrets** – `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`,
   `CLOUDKIT_MANAGEMENT_TOKEN`.
5. **CloudKit** – Actions → CloudKit schema → Run workflow; then CloudKit Console →
   `iCloud.at.binisoft.thalia` → Development → Deploy Schema Changes → Deploy.
6. **TestFlight** – a commit with `[testflight]` (or Actions → TestFlight → Run workflow).

## After a model change

`cloudkit/schema.ckdb` → CloudKit schema workflow → Deploy Schema Changes to Production → TestFlight.
New fields are optional or have a default; never rename or remove a synced field.

## Local development

```bash
make check                                             # no Mac needed
cp Config/Local.xcconfig.example Config/Local.xcconfig # set DEVELOPMENT_TEAM (Mac, signed runs)
make open
```
