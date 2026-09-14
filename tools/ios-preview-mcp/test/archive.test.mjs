import assert from "node:assert/strict";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { resolveSimulatorArchive } from "../lib/archive.mjs";

const root = resolve("preview-artifacts");

test("accepts a ZIP inside the configured preview-artifacts directory", () => {
    assert.equal(resolveSimulatorArchive(join(root, "LidlLean.app.zip"), root), join(root, "LidlLean.app.zip"));
});

test("rejects a ZIP outside the configured preview-artifacts directory", () => {
    assert.throws(() => resolveSimulatorArchive(resolve(root, "..", "outside", "LidlLean.app.zip"), root), /inside/);
});

test("rejects a non-ZIP archive", () => {
    assert.throws(() => resolveSimulatorArchive(join(root, "LidlLean.ipa"), root), /\.zip/);
});

test("publishes the complete MCP tool surface without a cloud credential", async () => {
    const serverPath = resolve(dirname(fileURLToPath(import.meta.url)), "../server.mjs");
    const transport = new StdioClientTransport({
        command: process.execPath,
        args: [serverPath],
        env: { ...process.env, APPETIZE_API_TOKEN: "", APPETIZE_ALLOW_PUBLIC_PREVIEW: "0" },
        stderr: "pipe"
    });
    const client = new Client({ name: "ios-preview-mcp-test", version: "1.0.0" }, { capabilities: {} });

    try {
        await client.connect(transport);
        const tools = await client.listTools();
        assert.deepEqual(tools.tools.map((tool) => tool.name), [
            "ios_preview_upload",
            "ios_preview_start",
            "ios_preview_screenshot",
            "ios_preview_ui_tree",
            "ios_preview_tap",
            "ios_preview_swipe",
            "ios_preview_type",
            "ios_preview_restart",
            "ios_preview_end"
        ]);
        const upload = await client.callTool({
            name: "ios_preview_upload",
            arguments: { archivePath: join(root, "LidlLean.app.zip") }
        });
        assert.equal(upload.isError, true);
        assert.match(upload.content[0].text, /APPETIZE_ALLOW_PUBLIC_PREVIEW/);

        const start = await client.callTool({ name: "ios_preview_start", arguments: {} });
        assert.equal(start.isError, true);
        assert.match(start.content[0].text, /buildId/);
    } finally {
        await transport.close();
    }
});
