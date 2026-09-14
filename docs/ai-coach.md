# AI coaching boundary

Updated: 2026-09-14

## What this is for

Give the user a concise second opinion about the current weekly plan without letting a language model become the source of calorie arithmetic, nutrition facts, or app state.

The planner remains useful offline. AI is an explicitly triggered interpretation of a previewed aggregate snapshot, never an autonomous health decision.

## Invariants

1. The API key never enters source control, UserDefaults, logs, or an AI prompt. Enforced by the Keychain store and request builder.
2. Nothing is sent until the user previews the aggregate and taps Generate with consent enabled. Enforced by the AI sheet.
3. The prompt contains no names, barcodes, meal entries, raw Health samples, dates, location, or identifiers. Enforced by `AICoachSnapshot` and prompt tests.
4. Model output can never mutate goals, food logs, Health data, or the shopping basket. Enforced by the one-way response-only UI seam.
5. AI failure never changes or hides deterministic planning. Enforced by keeping the planner and AI client independent.

## Components

| Component | Owns | Autonomy | Fails how |
|---|---|---|---|
| Snapshot builder | Minimal numeric aggregate | Human-triggered | Refuses unconfigured targets |
| Free-model selector | Highest-ranked currently free text model | Human-triggered | Falls back to OpenRouter's free router |
| OpenRouter client | One bounded advisory request | Human-triggered | Returns an actionable error and no advice |
| Keychain store | API key lifecycle | Human-triggered | Leaves the previous key intact on failed writes |
| AI sheet | Preview, consent, trigger, and response | Human-triggered | Dismissal discards the response |

## Seams

| From -> To | Carrier | Contract | On failure |
|---|---|---|---|
| Planner to snapshot | In-process value | Totals, targets, deficits, remaining budget, counts | Generate remains unavailable without configured targets |
| Sheet to Keychain | Security framework call | One opaque API-key string | Visible storage error; never falls back to preferences |
| Selector to OpenRouter | HTTPS GET | Public model catalog sorted by intelligence; zero-priced text models only | Use `openrouter/free` |
| Client to OpenRouter | HTTPS POST | Two-message chat completion with `data_collection: deny` | Show HTTP, decoding, timeout, or rate-limit error |
| Client to sheet | In-memory value | Advice text and actual model identifier | Previous successful advice remains visible during a retry |

Dependency direction points from the UI to stable aggregate and client contracts. Deterministic planning does not import or depend on AI code.

## Failure model

Retries create only advisory responses and no durable side effects. Concurrent Generate taps are disabled. Malformed responses are rejected. A stale free-model catalog cannot persist because selection happens per request. If privacy filtering leaves no eligible provider, the request fails instead of relaxing the policy.

## Decisions

### Select the best current free model at request time

2026-09-14 - Status: settled

Query OpenRouter's model catalog using its intelligence ordering, choose the first zero-priced text model, and display the actual model used. Fall back to `openrouter/free` when discovery is unavailable.

**Rejected:** Hard-code a named free model - free availability and rankings change independently of app releases.

**Cost accepted:** Each coaching request can require one additional public catalog request.

### Keep the API key on the device

2026-09-14 - Status: settled

Store a user-supplied key in Keychain with this-device-only accessibility.

**Rejected:** Embed a shared key - an IPA is inspectable and a shared credential cannot be safely rate-limited per user.

**Rejected:** Add a proxy now - it creates a second service, deployment, secret store, and privacy boundary for a personal sideloaded app.

**Cost accepted:** The user must create and paste an OpenRouter key once.

### Send only a previewed numeric aggregate

2026-09-14 - Status: settled

The prompt excludes raw records and product identities and requests bounded coaching language.

**Rejected:** Send full meals or Apple Health samples - the extra sensitivity is not necessary for useful weekly coaching.

**Cost accepted:** Advice cannot discuss a specific meal or diagnose a specific product choice.

## Open questions

1. Carried: a future proxy may replace user-managed keys if this becomes a distributed product. That decision depends on deployment and account ownership.

## Sources checked

- OpenRouter chat-completion API and bearer authentication, checked 2026-09-14: https://openrouter.ai/docs/api/api-reference/chat/send-chat-completion-request
- Free Models Router behavior and changing availability, checked 2026-09-14: https://openrouter.ai/docs/guides/routing/routers/free-router
- Model-catalog intelligence sorting, checked 2026-09-14: https://openrouter.ai/docs/api/api-reference/models/get-models
- Provider `data_collection: deny` routing, checked 2026-09-14: https://openrouter.ai/docs/guides/routing/provider-selection
