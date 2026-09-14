# LidlLean

LidlLean is a private, iPhone-first nutrition companion for a data-driven cut. It logs food locally, reads selected Apple Health activity, looks up German barcodes, and makes high-protein shopping easier.

## Windows-first build path

Windows is the development machine. GitHub Actions supplies the temporary macOS/Xcode environment that Apple requires to compile iOS applications. The workflow produces an unsigned IPA. Sideloadly signs that IPA with your Apple ID and installs it on your iPhone.

1. Create a private GitHub repository and push this folder.
2. In the Actions tab, run **Build iOS IPA**.
3. Download the `LidlLean-unsigned-ipa` artifact.
4. On Windows, open Sideloadly, select that IPA, connect the iPhone, then sign and install using your Apple ID.
5. On iOS 16 or later, enable Developer Mode before first launch.

No Apple certificate, provisioning profile, or Apple password enters GitHub. The unsigned artifact is deliberate: Sideloadly owns the personal signing step.

For a browser-hosted iOS UI preview on Windows, the same workflow also produces `LidlLean-simulator-app`. It is a zipped simulator `.app` for Appetize, not an installable iPhone IPA. The local MCP setup and privacy boundary are in [iOS Preview MCP](tools/ios-preview-mcp/README.md).

HealthKit is an Apple capability. The app target declares `com.apple.developer.healthkit`, and CI verifies that the generated Xcode build uses that entitlement file. The final profile produced while Sideloadly signs the app is the authority: it must also contain HealthKit. A free Personal Team profile may omit the capability, which produces the exact “missing com.apple.developer.healthkit entitlement” error on the phone. Follow the [HealthKit signing guide](docs/healthkit-signing.md) to use an explicit App ID and regenerated profile from an Apple Developer Program team.

If direct HealthKit signing is unavailable, LidlLean has a free local bridge: import Apple's unzipped `export.xml`, or run the documented [daily Apple Health Shortcut](docs/health-shortcut.md), which sends only a daily summary to `lidllean://health-sync` and never uses a cloud proxy.

## Source layout

```
App/              SwiftUI app and screens
Core/             Domain model, food catalog, HealthKit and AI boundary
docs/             Architecture and product requirements
.github/workflows Reproducible hosted-macOS IPA build
project.yml       XcodeGen project definition
```

## Data sources and boundaries

- Barcode lookup uses Open Food Facts. Imported values must be checked against the package label.
- Apple Health is read-only in v1. Food logs stay in the local SwiftData store.
- Lidl catalogs are discovered from its public webpage and read through the webpage's flyer service. Many grocery offers exist only as flyer images; the structured product catalog does not cover every grocery. National flyers are not store availability guarantees.
- Plan computes weekly planning locally. Its optional AI review previews a name-free aggregate before consent, keeps the user's OpenRouter key in Keychain, selects the highest-ranked current free text model, and denies providers that collect data.

## Weekly planning

In Plan, set your weekly calorie budget and daily protein target. The weight-loss goal is independently configurable. The app reads fourteen calendar days of HealthKit resting/active energy and weight, allows food backdating, and asks you to review complete days before using them for weekly projections. Missing HealthKit values remain unknown. Meals are logged by the app, not automatically imported from other nutrition apps.

Suggestions use foods whose nutrition you have checked. Portion sizes fit today's remaining calorie and protein allowances. Matching Lidl listings require the same product name and an applicable validity window; otherwise availability and price remain unknown. Shopping totals show confirmed subtotals and the number of unmatched items. Ingredient/allergen verification remains a label check, not a product-name inference.

See [planning decisions](docs/weekly-planning.md) for calendar rules and calculation limits. CI runs executable Swift planning scenarios before the iOS archive. Compilation and arithmetic tests do not verify HealthKit permissions on your physical phone.

The optional AI review is documented in [AI coaching boundary](docs/ai-coach.md). It sends no food names, barcodes, raw Health samples, dates, location, or identifiers. OpenRouter and its selected provider still receive the previewed aggregate, and free-model availability is not guaranteed.
