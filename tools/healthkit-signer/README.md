# Experimental Windows HealthKit signer

This is a personal-development experiment, not an Apple-supported Windows signing product. No paid developer membership is required by Apple's current base HealthKit capability table, but **Apple issuance and iPhone acceptance remain unverified until a real account/device test**. Unofficial authentication can fail or trigger account security checks. Stop after an account error; do not repeatedly retry.

## What it does

- Authenticates interactively against Apple using local Anisette generation, not a public authentication proxy.
- Lets you explicitly select a recognized free Personal Team and confirm the bundle/device before account changes.
- Requests HealthKit (`HK421J6T7P`), reuses its encrypted local signing key, and never revokes certificates.
- Stops unless the returned profile authorizes HealthKit, your device, the bundle and signing certificate.
- Independently verifies Apple's profile CMS signature/trust, signed app identity, executable hashes and the developer signature before packaging a checked IPA.
- Does **not** install, uninstall, automatically refresh, accept account terms, or change the bundle identifier. Your current iPhone app is untouched.

The verifier is deliberately limited to LidlLean's single arm64 executable. Extensions and frameworks are rejected. It is not a general IPA security scanner. Apple/iOS still decides revocation and installation acceptance; no offline tool can guarantee those.

## Build

Run `.github/workflows/build-healthkit-helper.yml` in the private repository. It builds on Windows using Swift 6.0.3, MSVC and pinned SideSign source. No Apple credentials are passed to Actions. Download `LidlLean-Windows-HealthKit-helper-experimental` and extract it locally.

Alternatively, in a Windows Swift 6.0.3/MSVC x64 developer shell with Python and vcpkg:

```powershell
git clone https://github.com/SideStore/SideSign.git .build/healthkit-upstream
git -C .build/healthkit-upstream checkout 10b446fc6fc47fe81b60879dfb126d0c8098ec29
./tools/healthkit-signer/Build-Windows.ps1 -Source .build/healthkit-upstream -Output .build/healthkit-dist
```

The source overlay refuses a dirty or different upstream revision. Dependencies use upstream's unchanged `Package.resolved`; build refuses silent resolution changes. Keep the helper independent from the iOS app. It links GPL/AGPL components; source and license obligations must be reviewed before any redistribution. No public distribution is authorized by this experiment.

## Prepare local runtime dependencies

You need PowerShell 7, Python 3.10+, and OpenSSL (Git for Windows includes it at `C:\Program Files\Git\usr\bin\openssl.exe`). The compiled artifact must include Swift runtime DLLs. `LidlLeanSigner.exe --self-test` exercises startup without credentials or network.

Local Anisette needs the arm64 `libCoreADI.so` and `libstoreservicescore.so` libraries from an authentic Apple Music Android APK. Obtain the APK from Apple, not a random mirror. The helper does not redistribute these proprietary libraries. From the extracted helper folder:

```powershell
python ./Setup-LocalDependencies.py --apple-music-apk C:/Downloads/AppleMusic.apk --destination ./adi
```

This extracts only those two libraries and downloads public root certificates from Apple's PKI website into `apple-roots.pem`. It prints library hashes but cannot establish APK authenticity for you. No login occurs here. If the APK layout has changed, setup stops.

## Sign locally

Find the iPhone UDID in Apple's Windows device software. Use the **same actual bundle identifier and Apple team as the existing installation** if preserving an in-place upgrade. Sideloadly may have rewritten the identifier; do not guess or delete the existing app if installation fails.

```powershell
./Start-HealthKitSigning.ps1 -Ipa C:/Downloads/LidlLean-unsigned.ipa `
    -Udid YOUR_IPHONE_UDID -AdiLibraries ./adi
```

Enter a strong local vault password, your Apple Account email/password, and Apple's verification code in the local console. Never send these to an assistant, add them to command arguments, record a terminal transcript, or upload the vault. Account terms/repair must be completed manually at Apple's site. The helper does not save the Apple password or login session.

Confirm `PROVISION` for the selected team/device/app. On first run, `CREATE` separately confirms creation of a development certificate, which consumes a slot. If Apple refuses due to a certificate limit, stop. There is no automatic revocation. You can instead place a matching encrypted P12 at `%LOCALAPPDATA%\LidlLeanSigner\TEAMID.p12` using the vault password. Losing that key requires manual account recovery; do not delete the vault casually.

The ACL-restricted vault contains encrypted device state, encrypted P12, the last profile and uniquely named working copies. A file lock prevents concurrent runs. Partial failure can leave a registered App ID/device or certificate; retry reuses known App IDs/devices and the saved key. A network interruption during certificate issuance can require manual recovery. No retry automatically creates or revokes additional certificates.

Success prints the checked IPA path, expiry and SHA256. **This is not yet a device-tested app.** Install only through a tool that preserves the existing signature/profile. Re-signing it in Sideloadly can remove HealthKit again. Do not delete your existing app. The final acceptance check is an in-place install and the native Health permission prompt. Free provisioning normally expires after seven days; renew using the same vault and identity.

## Tests and evidence

```powershell
python -m unittest discover -s tools/healthkit-signer -p 'test_*.py' -v
```

See [design and evidence](../../docs/windows-healthkit-helper.md). Offline tests, a successful build and profile inspection are separate from physical-device verification. Never report the last one based on the first three.
