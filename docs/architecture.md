---
type: decision
title: LidlLean architecture
description: Local-first nutrition, training and shopping boundaries and their rejected alternatives.
tags: [architecture, nutrition, training, shopping, privacy]
timestamp: 2026-09-18T00:00:00Z
---

# Architecture decision record: LidlLean

## Goal

Give one person an attractive, reliable daily system for logging food and using activity context to make informed weight-loss decisions, without turning their private health history into a cloud product.

The app must remain valuable offline. Barcode catalog, HealthKit, hosted build, Lidl offers, and AI are conveniences around the local food journal, not dependencies of it.

## Invariants

- Food history always remains on-device and editable by its owner.
- A catalog correction never rewrites nutrients in an already logged meal.
- A barcode or network failure never blocks a manual food entry.
- Apple Health data never leaves the device in v1.
- An AI request sends no identifiers, food names, barcodes, raw HealthKit samples, or location, and only follows visible consent.
- The public repository never receives signing material, Apple credentials, or OpenRouter keys.

## Components

| Component | Owns | Correctness criterion | Autonomy |
| --- | --- | --- | --- |
| SwiftUI experience | Navigation, data entry, visual hierarchy | User can understand today at a glance and log in seconds | Human-triggered |
| Local journal | Foods, immutable nutrient snapshots, targets | Relaunch preserves exact log totals | Human-triggered |
| Barcode catalog | EAN lookup and normalized nutrition draft | Never auto-logs imported data | Human-triggered |
| Health data adapter | Selected live HealthKit reads plus local XML/Shortcut fallback | Missing authorization leaves the journal usable and imported summaries remain local | Human-triggered |
| Shopping planner | Deterministic protein-density ranking | Ranking is explainable from stored values | Human-triggered |
| AI coach | One advisory response from minimum data | Cannot write records or set targets | Human-triggered |
| GitHub Actions build | Reproducible unsigned IPA | Artifact contains a successful device build | Autonomous |
| Sideloadly | User-owned personal signing and install | iPhone receives the exact chosen IPA | Human-triggered |

## Seams

| From -> to | Carrier and contract | Failure and ordering |
| --- | --- | --- |
| UI -> journal | SwiftData transaction: `MealEntry(foodName, grams, nutrientSnapshot, consumedAt)` | Save failure is shown; immutable entry ensures catalog edits cannot reorder history |
| scanner -> catalog | Direct async `lookup(EAN) -> FoodDraft` | Timeout, absent product, or malformed values produces a manual-entry path |
| catalog -> journal | Confirmed `FoodDraft` becomes local `Food`, then entry snapshot | User remains final writer of nutrition values |
| HealthKit -> dashboard | Read-only daily `ActivitySnapshot` | Denial or query error displays unavailable data, never blocks meals |
| UI -> OpenRouter | Explicit-consent macro summary | Rate limit or timeout returns a visible non-destructive error |
| GitHub source -> IPA | XcodeGen source, then Xcode archive and export | Workflow fails without publishing an artifact if project generation or archive fails |
| IPA -> iPhone | User chooses downloaded artifact in Sideloadly | Sideloadly signing error is local and cannot leak to CI |

## Failure model

- Local persistence failure: show an error and retain form input. No invisible retry creates a duplicate meal.
- Open Food Facts unavailable or malformed: use manual entry, preserving the barcode as optional context.
- HealthKit revoked: display no activity context. Nothing is deleted.
- Direct HealthKit unavailable: use the local imported Health summary, preserving unknown values rather than substituting zero.
- OpenRouter unavailable: show no suggestion. Totals and goals stay deterministic and local.
- Build failure: no IPA artifact is uploaded. The workflow logs compile errors only, not secrets.
- Re-run build: it creates a new commit-scoped artifact; it cannot overwrite food or health data.

## Rejected alternatives

| Alternative | Why rejected |
| --- | --- |
| Compile iOS natively on Windows | Apple’s Xcode/iOS SDK toolchain is macOS-only. A Windows executable cannot produce this native HealthKit app. |
| Remote desktop to a rented Mac | Adds interactive setup and persistent credential exposure. Ephemeral CI is more reproducible for an IPA-only workflow. |
| Commit a generated `.xcodeproj` | Generated project metadata creates noisy drift. XcodeGen makes the build definition reviewable. |
| Put the OpenRouter key in the app | An IPA is inspectable. A user-entered Keychain key is safer for a personal app. |
| Reverse-engineer Lidl Plus | Private endpoints and credentials are brittle and outside the app’s trust boundary. |
| Let AI calculate targets or automatically log food | Non-deterministic advice must not mutate health-adjacent records. |

## Deferred scope

Camera-based food recognition, recipe planning, cloud sync, and a proxy-backed AI service are later stages with separate design records. Optional label-based nutrient tracking is described below.

## Training and wellbeing subsystem

### Goal

Turn LidlLean into one calm, motivating daily fitness product where nutrition, a planned calisthenics session, recovery, and weekly progress reinforce each other without conflating their data or encouraging unsafe behaviour.

### Invariants

- A completed workout is an explicit local record, never inferred from opening a screen or an Apple Health estimate.
- Training plans are versioned program data. Editing a future plan never rewrites a completed workout.
- Nutrition targets, workout completion, and wellbeing signals have separate owners and can fail independently.
- Exercise media is optional. A failed remote demo never blocks starting, completing, or recording a session.
- The app rewards showing up, completing a planned session, and recovery. It never rewards injury-risky volume or calorie restriction.

### Components

| Component | Owns | Correctness criterion | Autonomy |
| --- | --- | --- | --- |
| Program library | The imported four-week push, pull, core, skill, and rest-day definitions from the calisthenics program | A date deterministically resolves to one session or recovery day | Deterministic |
| Workout journal | Explicit completed session, duration, and optional notes | One session can be recorded once per program day | Human-triggered |
| Training experience | Today’s session, exercise flow, rest guidance, and completion confirmation | A user can start or complete today’s session without navigating a dense schedule | Human-triggered |
| Daily cockpit | Read-only synthesis of food, activity, session, and recovery state | It never mutates health, meals, or workouts as a side effect of display | Read-only |

### Seams and failures

| From -> to | Carrier and contract | Failure and ordering |
| --- | --- | --- |
| Program library -> training experience | Immutable `TrainingDay` value | Missing or malformed program data produces a recovery state, not a fabricated workout |
| Training experience -> workout journal | SwiftData `WorkoutRecord(programDayID, completedAt, duration, note)` | Stable program-day ID prevents duplicate completion; save failure leaves the session visibly incomplete |
| Workout journal -> daily cockpit | Read-only date query | An absent record shows “not logged”, never “missed” or “failed” |
| Exercise -> demo media | Optional HTTPS URL | Failed media shows concise written form guidance and retains all controls |

### Rejected alternatives

| Alternative | Why rejected |
| --- | --- |
| Embed the existing HTML page in a web view | It preserves desktop density, localStorage state, and a separate visual system instead of building a coherent native app. |
| Make workouts a subpage of the food planner | Training has a different daily rhythm and a durable completion record, so it needs a first-class destination. |
| Import partner tracking into LidlLean | The program is for two people, but LidlLean is a private single-user health product. Partner comparison stays outside the personal journal. |
| Copy YAZIO’s or the webpage’s exact visual language | We adopt their clarity, motivation, and hierarchy, not their trade dress, palettes, or layouts. |

## iPhone-first product-surface redesign

### Goal

Make the daily loop feel like a confident personal operating system: understand the day in seconds, log a food in a few intentional taps, decide what to buy, and understand the week without reading an instruction manual.

### Invariants

- The primary action for each tab is reachable in the lower half of an iPhone 11 screen and has a minimum 44-point hit target.
- A screen never makes the user interpret a dense block of explanatory text before they can take its primary action.
- The visual system uses one accent for state and action, not a different decorative color for every card.
- Content adapts to the safe area, Dynamic Type, and narrower iPhones. No screen hard-codes iPhone 11 pixels.
- A missing network, Health, or AI integration looks like a clear state with a recovery action, never like an unfinished interface.

### Components and seams

| Component | Owns | Carrier | Failure behavior |
| --- | --- | --- | --- |
| Shell navigation | Four stable top-level destinations and cross-tab quick actions | Tab selection binding | A tab remains reachable even when its content is empty |
| Design system | Color roles, typography, surfaces, spacing, buttons, and data tiles | Shared SwiftUI components in AppTheme.swift | Views fall back to native controls rather than bespoke layout |
| Daily dashboard | Today’s calorie, macro, activity, and meal priorities | Read-only derived totals from SwiftData and Health adapter | Displays an explicit unavailable state without blocking logging |
| Food capture | Scanner, lookup, saved food, and manual entry modes | Local draft state -> confirmed SwiftData transaction | Manual logging remains available when scan or lookup fails |
| Shopping and plan | Public Lidl data and deterministic weekly suggestions | Existing catalog and planner contracts | Cached or empty states retain their actionable primary path |

The shell depends on the shared visual system. Feature screens depend on the data models and service contracts but not on one another. The design system must not own product logic, which keeps visual redesigns reversible.

### Rejected alternatives

| Alternative | Why rejected |
| --- | --- |
| iOS 26 system `TabView` shell | Its Liquid Glass container rendered this app's root as a 137.5-point-inset floating surface on the iPhone 11 simulator. A small owned tab strip keeps the familiar four destinations while preserving full-screen geometry and explicit accessibility labels. |

The app sets `UIDesignRequiresCompatibility` while it is built with the iOS 26 SDK. This is Apple's temporary compatibility switch for the Liquid Glass transition and prevents the system from presenting LidlLean as an inset scene. It must be removed when the design has been fully revalidated against the future SDK that ignores it.
| A card for every sentence | It creates visual noise, wastes the iPhone 11 viewport, and hides the user’s next action. |
| Hard-coded iPhone 11 dimensions | It fails on Dynamic Type, landscape, and future iPhones. SwiftUI safe areas and adaptive grids preserve the intended hierarchy. |
| Copying YAZIO’s surface literally | The useful pattern is fast logging plus an at-a-glance dashboard, not another product’s colors, mascot, or layout. |

## Momentum loop

### Goal

Make the healthy action feel complete and visible without turning calorie restriction into a game. The loop is: log a real meal, see protein progress, intentionally close the day, then return to an understandable weekly record.

### Invariants

- Momentum never rewards eating less, skipping meals, or exceeding a calorie deficit.
- Scores are derived from the local journal. They cannot be claimed twice, forged by an interface state, or require a network request.
- A day earns completion from at least one logged meal. Protein pacing and reviewing the journal are additive, explainable missions.
- A missed day resets a streak without punishment, currency, countdowns, or dark-pattern recovery mechanics.
- All thresholds use the user's protein target and are shown as progress, not a medical recommendation.

### Components and seams

| Component | Owns | Carrier | Failure behavior |
| --- | --- | --- | --- |
| Momentum engine | Deterministic points, mission state, and consecutive-day streak | Immutable `MomentumDay` values derived from SwiftData queries | Empty history yields zero progress, never a fabricated streak |
| Today mission card | The current day's three actionable missions | Read-only `MomentumSnapshot` | Remains useful before the first meal is logged |
| Logging celebration | Immediate confirmation that a persisted meal advanced the loop | Pre-save and post-save local evaluation | Save error produces no celebration |
| Weekly path | Seven-day completion visibility | Same derived snapshot per day | Future days appear neutral rather than incomplete |

The journal remains the source of truth. The engine has no persistence or networking seam, which keeps its results reproducible and prevents reward state from becoming a second, conflicting record.

### Rejected alternatives

| Alternative | Why rejected |
| --- | --- |
| Artificial coins, chests, or streak repair purchases | They reward app retention instead of nutrition behavior and create pressure after a missed day. |
| Rewarding a calorie under-run | It could encourage unsafe restriction and would confuse a calorie budget with a health outcome. |
| Server-owned streaks | The app is local-first and should work privately offline. |

## Lidl public-web ingestion subsystem

### Goal

Turn Lidl's current German public flyer into browsable, actionable shopping data inside LidlLean, including actual flyer pages, structured products, prices, and persistent basket totals.

### Invariants

- The app always obtains flyer discovery metadata from Lidl's public `lidl.de` webpage.
- A Lidl response is never treated as nutrition truth. Nutrition is separately matched and visibly left unknown when confidence is insufficient.
- The last successfully decoded catalog remains available when Lidl is temporarily offline or changes markup.
- Refreshing or retrying never duplicates a basket item with the same offer identifier.
- The app does not authenticate to Lidl Plus, collect Lidl credentials, or claim store-specific availability without store-specific data.

### Components and seams

| Component | Input -> output | Failure behavior | Autonomy |
| --- | --- | --- | --- |
| Catalog discovery | `lidl.de` HTML -> Schema.org `OfferCatalog` sale events | Uses cached catalog or shows a real error | Human-triggered refresh plus six-hour cache |
| Flyer decoder | Selected public flyer identifier -> Lidl flyer JSON | Rejects invalid responses atomically | Called by discovery |
| Offer normalizer | Product dictionary -> stable `LidlOffer` records | Skips only records without a valid price | Deterministic |
| Flyer renderer | Page image URLs -> lazy in-app pages | An image can fail independently without losing the catalog | User-driven |
| Nutrition matcher | Offer title plus local verified foods -> optional nutrients | Unknown stays unknown; no invented zero values | Deterministic suggestion |
| Basket store | Confirmed offer -> SwiftData `ShoppingItem` | Stable offer ID prevents duplicate adds in the UI | Human-triggered |

The carriers are HTTPS GETs for public Lidl data, a six-hour atomic JSON cache for network handoff, immutable value types between decoder and UI, and SwiftData for the user's basket. Network ordering is irrelevant because only a completed catalog replaces the cache. The basket remains independent of refresh order.

### Rejected alternatives

- Opening a browser as the primary experience: it exposes the flyer but cannot calculate a basket.
- Parsing only flyer dates: it proves freshness but provides no shopping value.
- Treating page text as structured products: OCR-like text lacks reliable price-to-product boundaries.
- Sending flyer images to an LLM by default: expensive, non-deterministic, and unnecessary where Lidl already exposes structured public data.

## Connected daily routine

Updated: 2026-09-18

Goal: help the user decide what to eat, what to buy, and how to train with fewer daily decisions, while keeping their own targets and checked labels authoritative.

### Invariants

1. Optional nutrients are unknown when absent, including in historical meals. A measured zero is distinct from missing data.
2. Nutrient totals show their coverage; partial logs never claim dietary adequacy or diagnose a deficiency.
3. Shopping and workout completion require an explicit user action and a successful local save.
4. Existing meal snapshots and existing user targets retain their meaning. Changes are additive to the local data model.
5. The daily dashboard reads journal state; it never silently records a meal, workout, or purchase.

### Components and seams

| Component | Owns | Contract and failure | Autonomy |
| --- | --- | --- | --- |
| Nutrient values | Optional fibre, salt, calcium, iron, potassium and unit-safe scaling | Codable `Nutrients`; old payloads decode absent fields as nil; aggregate coverage counts known meal values | Deterministic |
| Food capture | Label values and explicit confirmation | Confirmed values become immutable meal snapshots; invalid optional values block saving with an explanation | Human-triggered |
| Daily routine | Read-only food, workout and basket summary with direct navigation | SwiftData queries and navigation closures; unavailable integrations do not prevent local actions | Read-only |
| Shopping checklist | Saved-food portions over a chosen number of days, manual staples, purchased state | Explicit SwiftData save; unknown price stays unknown; failure rolls back and is visible | Human-triggered |
| Guided training | Exercise checklist, actual duration and optional reflection | Local draft until confirmed `WorkoutRecord`; save failure keeps draft available | Human-triggered |

UI depends on pure nutrition values and the existing journals. No new server or provider boundary is introduced. Repeated checklist toggles set a value; repeated completion is guarded by the existing program-day identifier. Editing a saved label does not affect historic meal snapshots. Shopping drafts do not mutate the journal or automatically purchase anything. Cancellation discards only unsaved form state.

### Decisions

- Track label nutrients with explicit units and coverage, without prescribing reference targets. Rejected: filling missing values with generic food estimates, which would create false precision. Cost: users must supply labels for coverage to improve.
- Extend the existing basket with a reusable-food builder and reversible bought state. Rejected: automatic multi-day menus from protein density alone, which cannot account for dietary variety, ingredients, or preferences. Cost: users choose their staples and portions once per addition.
- Keep the existing owned tab strip and visual palette; make Today prioritize food and training actions. Rejected: a replacement navigation framework, already ruled out by the iOS geometry evidence above. Cost: explicit cross-tab navigation remains owned by the shell.
- Mount each tab on first visit and retain it for the session. Hidden tabs are excluded from hit testing and accessibility. Rejected: recreating food forms and workout checklists on each switch. Cost: visited screens retain their small local drafts in memory.
- Keep exercise checkoffs as session drafts, while only a confirmed workout counts toward history. Rejected: inferring completion from elapsed time or checked exercises. Cost: one explicit save at the end of a workout.

Verification: native iPhone simulator interactions, legacy nutrient decoding and coverage scenarios, and an unsigned device build. Windows cannot execute SwiftUI or SwiftData; hosted macOS remains the native verification environment.

Nutrient units follow the [Open Food Facts nutrition schema](https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/product_nutrition/), checked 2026-09-18: normalized `_100g` mineral values are grams, irrespective of contributor `_unit` fields. The adapter converts calcium, iron and potassium to milligrams. Fibre and salt remain grams. Optional label values are not sent to the AI coach.

### Verified constraints

On 2026-09-18, [native build 35332522414](https://github.com/AliAlpOezer/LidlLean/actions/runs/35332522414) verified source revision `9ebf2d8`: fourteen nutrient checks, a separate-process migration from the preceding persisted schema, five iPhone 11 UI journeys, twenty-three planning checks, AI privacy checks, live Lidl ingestion and an unsigned device archive. The migration fixture proves that existing targets and macro snapshots survive, old optional nutrients remain unknown, and editing a food does not rewrite its prior meal snapshot. This is simulator and hosted-macOS evidence, not physical-phone HealthKit validation.

The full-bleed screenshot check samples the upper canvas gutters because center pixels can legitimately contain dark heading text. UI tests must scroll targets above the owned tab bar before tapping: SwiftUI can report a control beneath that bar as hittable. The status-bar background is explicitly painted to keep scrolled content out of the system clock area. These constraints were confirmed against captured iPhone 11 screenshots on iOS 26.5.
