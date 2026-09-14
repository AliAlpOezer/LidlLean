# Requirements

## v1 outcomes

- Set calorie and protein targets.
- Add food by camera barcode, typed barcode, or manual entry.
- Confirm imported product nutrition before creating a meal entry.
- Log grams and meal type, then see daily calories and macros.
- Read steps and active energy from Apple Health if authorized.
- Discover the current flyer from Lidl Germany's official webpage, decode its live public catalog into structured products, prices, links, and all flyer pages, and cache the last successful catalog for six hours.
- Add offers to a persistent basket with quantity, planned grams, checkout total, calorie estimate, and protein estimate. Nutrition estimates must come from verified local foods or a small explicit reference table; unknown values remain visibly unconfirmed.
- Calculate a Monday-to-Sunday plan from reviewed food logs and available Apple Health energy records.
- Recommend portions from nutrition labels the user has confirmed, with exact Lidl offer matches when available.
- Offer an explicitly triggered OpenRouter interpretation of a previewed aggregate snapshot. The core plan remains deterministic and useful without it.

## Visual direction

The app should feel calm, assured, and modern rather than clinical or decorative: a light neutral canvas, white surfaces, deep navy hierarchy, cobalt actions, restrained semantic accents, large numerals, and one clear primary action per section. The portrait layout must be verified at the iPhone 11's 414-point width, preserve 44-point tap targets, avoid compressed three-column metrics, and load only the visible flyer page. Dynamic Type, VoiceOver labels, contrast, and reduced-motion settings remain first-class.

## Acceptance criteria

- Meal entries persist after relaunch with their original nutrient snapshot.
- Barcode lookup failure leaves manual entry ready to use.
- Health authorization denial does not disable any food function.
- The generated target points to `App/LidlLean.entitlements`, where `com.apple.developer.healthkit` is true, and CI fails if either condition changes.
- The OpenRouter key is stored only in Keychain, the exact prompt is previewed before consent, and AI output cannot mutate app records.
- The app never contains a committed API key or signing credential.
- The CI artifact is an IPA exported only after a successful Xcode archive.
