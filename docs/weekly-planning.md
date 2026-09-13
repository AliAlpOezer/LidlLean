# Weekly planning decision

Checked 2026-09-13. Goal: explain yesterday, track the user's Monday-to-Sunday intake goal, and propose useful groceries with quantified portions.

Invariants: absent Health energy is unknown; only reviewed food days contribute to remaining-week projections; editing a reviewed day invalidates its review; exercise calories are never counted twice; suggestions never silently change the user's targets; product-name guesses never become confirmed nutrition.

| Component | Contract | Failure |
| --- | --- | --- |
| Journal and day review | SwiftData entries plus a signature of reviewed entry contents | A changed signature requires review again |
| Health history | Daily HealthKit statistics, resting and active energy separately | Nil means unavailable, no zero substitution |
| Planner | Pure daily values and user targets -> weekly budget, yesterday balance, remaining protein | Incomplete past days suppress remaining-week average |
| Grocery suggestions | Saved food nutrition + optional exact Lidl title match -> grams, calories, protein, source | Without a verified match, no Lidl price or availability claim |
| UI | Planner output -> user-approved basket item | Suggestions remain proposals until added |

The planner depends on value types, not SwiftData, HealthKit, or networking. Date grouping uses local calendar days with Monday as week start, including daylight-saving changes. Settings and reviews are on-device; repeated refreshes replace Health results and do not insert meals. Basket additions use stable recommendation identifiers and explicit saving.

Decisions: use a user-entered calorie budget rather than infer a medical calorie prescription from a weight-loss rate. Show the difference between intake and recorded resting-plus-active energy as an estimate. Do not add workout calories separately. Do not automatically compensate for yesterday's excess by restricting today's target. Reject fuzzy automatic nutrition matching because matching 'salmon' also matches prepared dishes with different nutrients. The cost is fewer automatic recommendations until products are verified.

Verification: pure Swift scenarios cover full and partial weeks, missing energy, over-budget weeks, Monday rollover, daylight-saving dates, and recommendation portion arithmetic. Device Health authorization and real user history still require an iPhone test.

Sources: [Apple Health authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data), [NIDDK weight-model research](https://www.niddk.nih.gov/research-funding/at-niddk/labs-branches/laboratory-biological-modeling/integrative-physiology-section/research/body-weight-planner). Weight change is not a fixed short-term calorie-to-kilogram conversion.
