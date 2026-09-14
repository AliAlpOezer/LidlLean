# HealthKit signing boundary

## Decision

The source target owns the HealthKit declaration, but Apple owns the authority to place that declaration in the signed app. `App/LidlLean.entitlements` can request `com.apple.developer.healthkit`; it cannot grant the capability after Sideloadly signs the IPA.

The installable artifact must therefore be signed by a team whose provisioning profile contains the HealthKit entitlement. A free Personal Team profile is not a reliable path for this capability. The supported route is an Apple Developer Program team with an explicit App ID for `com.alial.lidllean`, HealthKit enabled on that App ID, and a regenerated development profile.

## Required signing sequence

1. Enroll in the Apple Developer Program if the current Sideloadly account is only a free Personal Team.
2. In Certificates, Identifiers & Profiles, register the explicit App ID `com.alial.lidllean`.
3. Enable the HealthKit capability on that App ID and save it.
4. Regenerate the development profile after changing the App ID. Existing profiles do not gain capabilities retroactively.
5. In Sideloadly, select the paid Developer Team or provide the regenerated profile and its matching signing certificate. The bundle identifier must remain `com.alial.lidllean`.
6. Remove the old install from the iPhone, install the newly signed IPA, and press Connect to Apple Health.
7. Approve the individual data types in the iOS Health permission sheet. The app remains usable if any category is declined.

If Sideloadly still reports a missing entitlement, inspect the profile it used. The profile, not the source plist, is the authority. Do not try to add the entitlement by editing the IPA after signing; iOS will reject the signature or strip the unauthorized key.

## Runtime behavior

The app maps a missing-entitlement error to a signing diagnosis. It does not claim that an in-app button can grant a restricted capability, and it never treats unavailable HealthKit values as zero.

