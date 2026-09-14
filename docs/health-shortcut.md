# Daily Apple Health Shortcut

This shortcut is the free alternative to a signed HealthKit integration. It runs on the iPhone, so the user grants Shortcuts access to Health data directly. LidlLean receives only the daily summary through its local URL scheme.

## Create it on the iPhone

1. Open Shortcuts and create a personal shortcut named `Sync health to LidlLean`.
2. Add `Find Health Samples` actions for today's active energy, resting energy, step count, walking + running distance, and Apple exercise time. Add a latest body-mass sample and body-fat sample if you use them.
3. For each result, add `Get Details of Health Samples` and `Calculate Statistics` to produce one daily total or latest value. Convert distance to kilometres and energy to kcal.
4. Add a `Text` action containing this URL. Insert the calculated Shortcut variables into the query values:

```text
lidllean://health-sync?date=YYYY-MM-DD&activeKcal=ACTIVE&restingKcal=RESTING&steps=STEPS&walkingKm=WALKING&exerciseMin=EXERCISE&weightKg=WEIGHT&bodyFatPercent=BODYFAT
```

5. Add `Open URLs` using that Text result. Run it once and approve the requested Health categories.
6. Add a personal automation at the time you want the daily sync. The iPhone may require confirmation depending on the automation type and iOS version.

Fields can be omitted when a category is unavailable. Do not use localized number formatting in the URL; use a decimal point and no thousands separators.

## Historical import

In Health, tap the profile picture, choose **Export All Health Data**, and save the ZIP to Files. Open the ZIP in Files to extract it, then select the contained `export.xml` from LidlLean's **Import Health export** button. The app stores normalized daily summaries locally.

