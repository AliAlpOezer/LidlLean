---
type: constraint
title: HealthKit signing boundary
description: Free capability eligibility, provisioning requirements and preservation of local app data.
tags: [healthkit, signing, privacy]
timestamp: 2026-09-19T00:00:00Z
---

# HealthKit signing boundary

## Decision

The source target owns the HealthKit declaration, but Apple owns the authority to place that declaration in the signed app. `App/LidlLean.entitlements` can request `com.apple.developer.healthkit`; it cannot grant the capability after Sideloadly signs the IPA.

The installable artifact must be signed by a team whose provisioning profile contains HealthKit. Apple's [supported capabilities table](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) explicitly includes base HealthKit for free Apple Developer accounts. Checked 2026-09-18 against the HTML checkmark cells; text-only rendering loses those cells. Earlier paid-only guidance here was incorrect. HealthKit Estimate Recalibration is a separate capability and is not requested by this app.

## Available routes

- With a Mac: sign into Xcode, select the free Personal Team, enable automatic signing and HealthKit, then run on the connected iPhone. Apple manages personal certificates and profiles through Xcode. [Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account/) include seven-day profile expiry.
- Windows only: the [experimental local helper](../tools/healthkit-signer/README.md) requests HealthKit through Apple's provisioning service and independently checks its output. Account/device acceptance is not established by a successful build. See its [design, evidence and limits](windows-healthkit-helper.md).
- If native provisioning fails: use the [local Shortcut/import bridge](health-shortcut.md). It does not grant an entitlement and is not native HealthKit.

Sideloadly's free signing support does not establish that it can request this capability. Do not re-sign an independently checked artifact with another signer: its replacement profile may omit HealthKit. Do not edit an IPA after signing.

## Preserve app data

Do not delete the installed app to repair signing. Its local SwiftData journal may be lost. Verify the existing installed team and actual bundle identity first; Sideloadly may have rewritten the identifier. Attempt an in-place update only with compatible identity and preserve a recoverable device/app backup. If iOS refuses the update, stop rather than uninstalling automatically.

## Built metadata is also required

On 2026-09-19, inspecting the previous `9ebf2d8` unsigned IPA showed no Health/camera usage descriptions or `lidllean` URL scheme despite their presence in the checked-in plist. XcodeGen's `info.properties` rewrites that file during generation. `project.yml` now owns all these properties, and `check_app_metadata.py` checks the final archive. This is separate from entitlement authorization. Do not use the older IPA for the native signing experiment.

## Runtime behavior

The app maps a missing-entitlement error to a signing diagnosis. It does not claim that an in-app button can grant a restricted capability, and it never treats unavailable HealthKit values as zero.
