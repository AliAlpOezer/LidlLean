# Requirements

## v1 outcomes

- Set calorie and protein targets.
- Add food by camera barcode, typed barcode, or manual entry.
- Confirm imported product nutrition before creating a meal entry.
- Log grams and meal type, then see daily calories and macros.
- Read steps and active energy from Apple Health if authorized.
- Discover the current flyer from Lidl Germany's official webpage, decode its live public catalog into structured products, prices, links, and all flyer pages, and cache the last successful catalog for six hours.
- Add offers to a persistent basket with quantity, planned grams, checkout total, calorie estimate, and protein estimate. Nutrition estimates must come from verified local foods or a small explicit reference table; unknown values remain visibly unconfirmed.
- Request a constrained, opt-in OpenRouter daily insight.

## Visual direction

The app should feel like a calm performance dashboard, not a hospital record or an overdecorated diet app: ink-black base, sharp lime accent for progress, warm off-white type, dense but breathable cards, large numerals, rounded geometry, and a clear single primary action. Dynamic Type, VoiceOver labels, contrast, and reduced-motion settings remain first-class.

## Acceptance criteria

- Meal entries persist after relaunch with their original nutrient snapshot.
- Barcode lookup failure leaves manual entry ready to use.
- Health authorization denial does not disable any food function.
- The app never contains a committed API key or signing credential.
- The CI artifact is an IPA exported only after a successful Xcode archive.
