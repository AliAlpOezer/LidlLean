# Free Health sync architecture

## Goal

Make the app useful with the user's Apple Health data without claiming a HealthKit entitlement that the installed signature does not possess.

## Invariants

- Health data stays in the app's local Application Support directory and is never uploaded by this bridge.
- A repeated Shortcut run for the same date replaces that day's imported fields; it never doubles a total.
- An XML import preserves supported historical days and ignores unsupported Health record types.
- Missing values remain missing. The importer never substitutes zero for unavailable data.
- The app never presents imported values as live HealthKit authorization.

## Components

| Component | Owns | Correctness criterion |
| --- | --- | --- |
| `HealthImportStore` | Local Codable daily summaries and atomic persistence | A relaunch returns the same imported values |
| XML parser | Health export records and unit conversion | Supported activity/body types are normalized into local calendar days |
| URL receiver | `lidllean://health-sync` validation and idempotent merge | A malformed or repeated URL cannot corrupt totals |
| `HealthKitClient` fallback | Chooses live HealthKit values when available, otherwise imported values | The app remains useful without the entitlement |
| SwiftUI importer | User-selected XML file and feedback | File access is security-scoped and errors are visible |

## Seams

| From -> to | Carrier and contract | Failure behavior |
| --- | --- | --- |
| Apple Shortcuts -> app | `lidllean://health-sync?date=YYYY-MM-DD&activeKcal=...` | Invalid URL or unsafe value is rejected and shown in an alert |
| Files -> XML parser | User-selected unzipped `export.xml` security-scoped URL | Unreadable, malformed, or unsupported exports are rejected without changing stored data |
| Import store -> planner | Local actor calls returning daily energy, weight, and today's snapshot | Imported data fills only missing live HealthKit values |

## Shortcut payload

The shortcut sends one day at a time using these optional fields: `activeKcal`, `restingKcal`, `steps`, `walkingKm`, `exerciseMin`, `weightKg`, and `bodyFatPercent`. The date is required. The app URL scheme is registered in `project.yml`.

## Rejected alternatives

- Editing the entitlement plist at runtime: iOS validates entitlements before the process starts.
- Sending Health values through a cloud proxy: unnecessary exposure for a personal journal.
- Summing every XML record without deduplication: exports can contain repeated records from multiple sources.
- Treating the XML export as a live HealthKit connection: it would mislead the user about freshness and permissions.

