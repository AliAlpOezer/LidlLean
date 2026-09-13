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

HealthKit is an Apple capability, so the final signing profile must include its entitlement. If Sideloadly reports that your Personal Team cannot provision HealthKit, enroll in the Apple Developer Program and create a development profile with HealthKit enabled. The app itself still builds on GitHub's macOS runner either way.

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
- Lidl Plus credentials are never requested. Offers stay deferred until a permitted source is available.
- The AI coach uses the user-provided OpenRouter key saved in Keychain. It only receives macro totals and goals after an explicit in-app consent toggle.

`openrouter/free` is used instead of pinning a free model because availability changes. It is a low-volume assistant, not a nutrition authority.
