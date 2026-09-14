# LidlLean iOS Preview MCP

This local MCP server gives Codex a Playwright-like control loop over an Appetize iOS simulator: upload a simulator build, start it, inspect screenshots and the accessibility UI tree, then tap, type, swipe, restart, or end the disposable session.

It is a UI preview tool. It cannot access your personal Apple Health data, and it must never receive your production OpenRouter key.

## Prerequisites

- Node.js 24 or newer
- An Appetize organization API token
- A GitHub Actions artifact containing `LidlLean.app.zip` from the simulator build

Install dependencies and Chromium once:

```powershell
cd C:\Users\alial\dev\LidlLean\tools\ios-preview-mcp
npm install
npx playwright install chromium
```

Set secrets in your Windows user environment. Do not put a real token in `.env.example` or any tracked file:

```powershell
[Environment]::SetEnvironmentVariable("APPETIZE_API_TOKEN", "your-token", "User")
[Environment]::SetEnvironmentVariable("APPETIZE_ALLOW_PUBLIC_PREVIEW", "1", "User")
[Environment]::SetEnvironmentVariable("IOS_PREVIEW_ARTIFACT_DIR", "C:\Users\alial\dev\LidlLean\preview-artifacts", "User")
```

Restart the terminal after changing user environment variables.

## Codex MCP registration

Add this local server to the harness configuration using the command below. The server communicates exclusively through standard input/output, so diagnostic output must stay on standard error.

```json
{
  "mcpServers": {
    "lidllean-ios-preview": {
      "command": "node",
      "args": ["C:\\Users\\alial\\dev\\LidlLean\\tools\\ios-preview-mcp\\server.mjs"]
    }
  }
}
```

Restart Codex after registering the server. The available tools are `ios_preview_upload`, `ios_preview_start`, `ios_preview_screenshot`, `ios_preview_ui_tree`, `ios_preview_tap`, `ios_preview_swipe`, `ios_preview_type`, `ios_preview_restart`, and `ios_preview_end`.

## Preparing an artifact

The device IPA used by Sideloadly cannot run in Appetize. Download the separate simulator build artifact into the controlled local folder, then pass its full ZIP path to `ios_preview_upload`.

`ios_preview_upload` refuses paths outside `IOS_PREVIEW_ARTIFACT_DIR` and refuses anything that is not a ZIP containing an iOS `.app` bundle. Upload requires `APPETIZE_ALLOW_PUBLIC_PREVIEW=1` because Appetize build links are shareable by build ID.

Appetize currently provides `iphone11pro`, not the exact iPhone 11. Use this MCP for rapid visual and accessibility interaction. Keep the physical iPhone 11 and the existing macOS simulator test for final device validation.
