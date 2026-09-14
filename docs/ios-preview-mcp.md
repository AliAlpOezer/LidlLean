# iOS Preview MCP

Updated: 2026-09-14

## What this is for

Give a Windows-based developer and coding agent an inspectable, controllable iOS simulator session for LidlLean without treating a cloud simulator as a substitute for the user's physical iPhone.

The preview loop must make UI state observable through screenshots and accessibility-backed interactions. It must never expose personal Apple Health data or cloud credentials through the repository, build artifacts, or tool responses.

## Invariants

1. Appetize credentials always remain in the local process environment. Enforced by the MCP server rejecting startup without `APPETIZE_API_TOKEN` and never serializing configuration secrets.
2. The preview consumes only the simulator `.app.zip` artifact, never the device IPA. Enforced by a distinct CI artifact and server upload validation.
3. A tool reports a successful action only after a fresh screenshot or UI-tree read confirms a live session response. Enforced by the server's post-action stabilization and observable response payloads.
4. Simulator state is disposable and contains only test data. Enforced by starting a fresh session and never connecting Apple Health or a production OpenRouter key.
5. Interactions prefer stable accessibility identifiers over screen coordinates. Enforced by the MCP contract accepting element selectors first and documenting coordinate use as a fallback.

## Components

| Component | Owns | Autonomy | Fails how |
|---|---|---|---|
| GitHub Actions simulator build | A zipped simulator `.app` artifact | Autonomous | Build failure blocks preview upload |
| Local MCP server | Token loading, upload, one active session, tool contracts | Human-triggered | Returns a structured tool error without leaking credentials |
| Local bridge page | Appetize browser SDK lifecycle | Human-triggered through MCP | Browser or SDK failure ends the active session |
| Appetize session | Hosted simulator execution and semantic device actions | Human-triggered through MCP | Provider error or timeout is surfaced as unavailable |

## Seams

| From → To | Carrier | Contract | On failure |
|---|---|---|---|
| CI → developer | GitHub artifact | `LidlLean-simulator-app.zip`, containing a simulator `.app` | No upload is attempted |
| MCP server → Appetize API | HTTPS with `X-API-KEY` | ZIP upload, returns build ID | The server keeps no partial build ID and reports the provider response |
| MCP server → bridge page | Playwright page evaluation | Start session, tap, type, swipe, UI tree, screenshot | The server closes the failed browser/session and reports the action name |
| bridge page → Appetize | Official browser SDK | Build ID and session configuration | Session cannot be treated as live until `waitUntilReady` completes |

Dependency direction: the MCP server depends on the stable external Appetize API and local bridge protocol. The iOS app and CI workflow do not depend on the local MCP process.

## Failure model

- A missing token blocks upload and session start before a browser launches.
- A malformed archive is rejected before upload where detectable; Appetize rejection is reported with no retry loop.
- A browser crash invalidates the local session reference. Later interaction calls require an explicit new session.
- Starting a second session ends the first one before replacing the reference, so the server has exactly one active session.
- Session-ending and browser-closing are idempotent.

## Decisions

### Use Appetize for the agent-controlled preview loop

2026-09-14 · Status: settled

Appetize provides a browser SDK with screenshots, accessibility-based taps, typing, swipes, and UI-tree inspection. This directly supports a small, transparent MCP surface.

**Rejected:** a Windows-hosted iOS Simulator - Apple distributes Simulator with macOS Xcode only.

**Cost accepted:** Appetize does not currently list the exact iPhone 11, only iPhone 11 Pro. It validates functional layout, while physical iPhone 11 and BrowserStack remain the final pixel and device checks.

### Keep BrowserStack as the exact-device verification path

2026-09-14 · Status: settled

BrowserStack offers a real iPhone 11 and Appium automation, but it is not the fastest browser-SDK loop and needs separate paid credentials. It remains the optional exact-device service.

**Rejected:** making BrowserStack the first MCP provider - its session model is Appium-centric rather than a simple browser SDK bridge.

**Cost accepted:** two providers may be used when exact device testing becomes necessary.

## Open questions

1. Carried: an Appetize organization token is required before a live session can be started. The local server can be built and tested without it.
2. Carried: we will add explicit SwiftUI accessibility identifiers to high-value controls after the live preview confirms the initial UI tree.
