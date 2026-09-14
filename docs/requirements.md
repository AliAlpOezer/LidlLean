# LidlLean product requirements

## Product promise

LidlLean is a private iPhone nutrition operating system for sustainable fat loss: fast food logging, realistic protein-aware planning, live Lidl Germany offer intelligence, and an AI coach that explains the user's own data. It must feel confident, premium, immediate, and native on an iPhone 11.

## Core experience

1. Today is a full-screen, full-bleed dashboard. It shows the daily calorie budget, protein progress, meals, activity context, a useful next action, and local momentum in one glance.
2. Logging is fast. The user can scan a German EAN barcode, confirm a product label, reuse recent foods, or enter a barcode-free food with a transparent estimate. A saved meal is immediately reflected in the day.
3. Lidl shopping is real. The app reads Lidl Germany's public current flyer, shows offer name, price, dates, and flyer evidence, then combines confirmed nutrition with the user's calorie and protein gap. Unknown nutrition is visibly unknown, never invented.
4. The weekly plan explains yesterday, the remaining weekly budget, protein pacing, weight trend when sufficient Health data exists, and specific buy suggestions with calories, protein, and money.
5. The AI coach is optional and advisory. It receives only a user-reviewed aggregate snapshot, explains patterns and tradeoffs, and cannot alter food, targets, Health data, or the basket.
6. Motivation supports health. Local missions reward logging a meal, reaching protein pace, and closing a journal day. They never reward under-eating, skipped meals, or engagement for its own sake.

## iPhone 11 visual contract

- Target viewport: 414 by 896 points in portrait, respecting the status bar, home indicator, Dynamic Type, and keyboard.
- The canvas reaches every screen edge. No page sheet, letterboxing, or unexplained black or empty band is allowed at the top or bottom.
- Content begins directly below the system status area and flows above the native tab bar. The tab bar remains stable across Today, Log, Shop, and Plan.
- The first viewport has a clear hierarchy: one daily hero, one next action, then supporting detail. Scrolling reveals depth rather than filler.
- Touch targets are at least 44 points. Native navigation, voice-over labels, contrast, and reduced-motion behavior are required.
- The visual language is purposeful: dark ink, off-white canvas, a focused lime action color, strong rounded type, generous but intentional spacing, and no generic template-card clutter.

## Non-negotiable data rules

- Journal and Health-imported data stay on the device.
- HealthKit is optional and read-only. Its absence never blocks tracking.
- Barcode and Lidl network failures always leave manual logging and cached data usable.
- A historic meal keeps its nutrition snapshot after a catalog item is corrected.
- Prices and availability retain source and date context. They are not claimed to be store-specific unless Lidl supplies store-specific data.
- Health-adjacent suggestions are explanatory, not medical advice or automatic prescriptions.

## Acceptance checks

- The iPhone 11 simulator proves the complete 414 by 896-point app window and retains a screenshot artifact for visual inspection of the full-bleed canvas.
- The live Lidl ingestion test decodes the current public German flyer.
- Planner, momentum, and AI-snapshot tests prove deterministic calculations and safety rules.
- The build produces both a simulator preview and an unsigned device IPA from the same source revision.
