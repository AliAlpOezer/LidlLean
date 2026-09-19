---
type: decision
title: Experimental Windows HealthKit signing helper
description: Local-only provisioning experiment, credential boundary, and acceptance gates.
tags: [healthkit, signing, windows, privacy]
timestamp: 2026-09-19T00:00:00Z
---

# Experimental Windows HealthKit signing helper

## Goal and invariants

Sign LidlLean for personal HealthKit use from Windows without a paid developer membership. Apple must issue the authority; this tool cannot manufacture it.

1. Apple passwords and login sessions never enter CI, arguments, logs, or the repository. Login is interactive and the session remains in memory.
2. Only the explicitly selected team, bundle identifier and device are provisioned. No certificate revocation, app deletion, installation, or automatic account repair.
3. A missing HealthKit entitlement, wrong identity, expired profile or wrong device stops the pipeline. A successful HTTP response is insufficient.
4. Signing keys and device provisioning state stay in a user-private local directory. Signing keys are password-encrypted and reused, never committed.
5. An output IPA is experimental until independently inspected and accepted by the physical iPhone. Compilation and synthetic tests are not device evidence.

## Components and seams

| Component | Contract and failure | Control |
|---|---|---|
| Pinned SideSign build | Source revision plus reviewed local overlay produces a Windows executable; build failure produces no release claim | Local/CI build, no Apple secrets |
| Interactive helper | Calls SideSign's Apple authentication and provisioning APIs; requests `HK421J6T7P`; rejects unsupported profiles | Human-triggered; no background refresh |
| Local encrypted state | Password-encrypted P12 and device state outside the repository; one exclusive run per directory; existing keys reused | Helper owns files |
| Independent inspector | Reads final IPA, profile and Mach-O entitlements; checks HealthKit, identity, expiry and device without using signer models | Read-only; fails closed |
| Installation | User installs the exact checked artifact while preserving app identity and data | Not automated by this helper |

The CLI depends on SideSign for Apple protocols and signing. The independent inspector does not. Files bridge signing and inspection; no session or key crosses into inspection. Partial output is not a verified output. Retrying lists existing App IDs/devices and reuses local keys. Ambiguous or exhausted account state stops rather than revoking anything. The helper does not retry account mutations automatically.

## Decisions and alternatives

2026-09-18, experimental: reuse SideSign at `10b446fc6fc47fe81b60879dfb126d0c8098ec29` with a narrow LidlLean command and HealthKit-preservation patch. Upstream currently has Windows binaries and Apple authentication/provisioning implementations. Cost: substantial upstream dependencies and undocumented Apple protocol changes; require compile and device verification.

Rejected: implement Apple's authentication/cryptography ourselves, patch the closed-source Sideloadly executable, put Apple login in hosted Xcode, use shared signing certificates, or assume a source entitlement grants permission. These either expand the credential risk or cannot establish authorization. A Shortcut remains the local fallback, not equivalent native HealthKit.

## Evidence and open acceptance checks

- [Apple capability table](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) lists base HealthKit for free Apple Developer accounts. Checked 2026-09-18 using the HTML checkmark cells, which text-only readers omit.
- [AltSign HealthKit patch](https://github.com/rileytestut/AltSign/pull/45) identifies `HK421J6T7P`; closed without device verification. Treat this mapping as an experimental upstream lead.
- [SideSign source](https://github.com/SideStore/SideSign/tree/10b446fc6fc47fe81b60879dfb126d0c8098ec29) is the protocol/signing dependency. Preserve its license attribution when building or sharing derivatives.
- Blocking live acceptance: user-local Apple login, a profile actually authorizing HealthKit, and a physical iPhone permission prompt. No claim of success before these exist.

See [helper instructions](../tools/healthkit-signer/README.md) and [signing boundary](healthkit-signing.md).

## Verification checkpoint, 2026-09-19

Twenty offline Python tests cover profile identity/expiry/HealthKit, unsafe archives, and full synthetic CMS signatures with tampering and unauthorized-certificate rejection. Synthetic certificates are test fixtures, not Apple-issued evidence. The first hosted Windows compile reproduced a missing pattern-matching operator after replacing upstream's entry point; the small upstream support operator was restored. Native build and account/device verification remain separate acceptance steps.

The prior device IPA failed the new built-metadata check because XcodeGen regenerated its plist without Health/camera usage descriptions or the URL scheme. The fix lives in `project.yml`, with an archive regression check. Rejected: injecting privacy descriptions while signing, because the unsigned build should be correct independently of the signer.
