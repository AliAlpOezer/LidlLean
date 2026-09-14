import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { chromium } from "playwright";
import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { assertSimulatorArchive, previewArtifactDirectory, resolveSimulatorArchive } from "./lib/archive.mjs";
import { uploadSimulatorArchive } from "./lib/appetize-api.mjs";

const directory = resolve(fileURLToPath(new URL(".", import.meta.url)));
const bridgePath = resolve(directory, "bridge.html");

function safeMessage(error) {
    const raw = error instanceof Error ? error.message : "Unknown preview error.";
    const secret = process.env.APPETIZE_API_TOKEN;
    return secret ? raw.replaceAll(secret, "[redacted]") : raw;
}

function textResult(value) {
    return { content: [{ type: "text", text: JSON.stringify(value, null, 2) }] };
}

function errorResult(error) {
    return { isError: true, content: [{ type: "text", text: safeMessage(error) }] };
}

class PreviewController {
    constructor() {
        this.browser = undefined;
        this.page = undefined;
        this.lastUploadedBuildId = undefined;
    }

    async start(configuration) {
        await this.end();
        try {
            this.browser = await chromium.launch({ headless: process.env.IOS_PREVIEW_HEADED !== "1" });
            this.page = await this.browser.newPage({ viewport: { width: 480, height: 960 } });
            await this.page.setContent(await readFile(bridgePath, "utf8"), { waitUntil: "domcontentloaded" });
            return await this.page.evaluate((config) => window.LidlLeanPreviewBridge.start(config), configuration);
        } catch (error) {
            await this.end();
            throw new Error(`Could not start the Appetize preview: ${safeMessage(error)}`);
        }
    }

    async invoke(method, argument) {
        if (!this.page) throw new Error("No active iOS preview session. Call ios_preview_start first.");
        try {
            return await this.page.evaluate(async ({ method, argument }) => {
                const bridge = window.LidlLeanPreviewBridge;
                return argument === undefined ? bridge[method]() : bridge[method](argument);
            }, { method, argument });
        } catch (error) {
            throw new Error(`Preview ${method} failed: ${safeMessage(error)}`);
        }
    }

    async end() {
        const page = this.page;
        const browser = this.browser;
        this.page = undefined;
        this.browser = undefined;
        if (page) {
            try { await page.evaluate(() => window.LidlLeanPreviewBridge?.end()); } catch (_) { /* Browser may already be gone. */ }
        }
        if (browser) await browser.close().catch(() => undefined);
        return { ended: true };
    }
}

const controller = new PreviewController();
const server = new McpServer({ name: "lidllean-ios-preview", version: "0.1.0" });

const selectorSchema = z.object({
    accessibilityIdentifier: z.string().min(1).max(200).optional(),
    accessibilityLabel: z.string().min(1).max(200).optional(),
    accessibilityHint: z.string().min(1).max(200).optional(),
    text: z.string().min(1).max(200).optional()
}).refine((value) => Object.values(value).some(Boolean), "Provide at least one element selector attribute.");

server.registerTool("ios_preview_upload", {
    description: "Upload a zipped iOS Simulator .app from the configured preview-artifacts directory to Appetize. This requires APPETIZE_API_TOKEN and APPETIZE_ALLOW_PUBLIC_PREVIEW=1 in the local environment.",
    inputSchema: { archivePath: z.string().min(1) }
}, async ({ archivePath }) => {
    try {
        if (process.env.APPETIZE_ALLOW_PUBLIC_PREVIEW !== "1") {
            throw new Error("Set APPETIZE_ALLOW_PUBLIC_PREVIEW=1 to acknowledge that Appetize build links are accessible to anyone with the link.");
        }
        const resolved = resolveSimulatorArchive(archivePath, previewArtifactDirectory());
        const archive = await assertSimulatorArchive(resolved);
        const uploaded = await uploadSimulatorArchive({
            archivePath: archive.archivePath,
            apiToken: process.env.APPETIZE_API_TOKEN,
            note: `LidlLean simulator preview: ${archive.filename}`
        });
        controller.lastUploadedBuildId = uploaded.buildId;
        return textResult({ ...uploaded, archive: archive.filename, next: "Call ios_preview_start with this buildId." });
    } catch (error) {
        return errorResult(error);
    }
});

server.registerTool("ios_preview_start", {
    description: "Start one disposable Appetize iOS simulator session. Appetize currently provides iPhone 11 Pro, not the exact iPhone 11. Use BrowserStack or the physical phone for final iPhone 11 validation.",
    inputSchema: {
        buildId: z.string().min(4).max(200).optional(),
        device: z.enum(["iphone11pro", "iphone12", "iphone13pro", "iphone13promax"]).default("iphone11pro"),
        osVersion: z.enum(["15.5", "16.2", "17.2", "18.2", "26.0"]).default("17.2"),
        appearance: z.enum(["light", "dark"]).default("light")
    }
}, async ({ buildId, device, osVersion, appearance }) => {
    try {
        const selectedBuild = buildId || controller.lastUploadedBuildId;
        if (!selectedBuild) throw new Error("Provide an Appetize buildId or upload a simulator archive first.");
        return textResult(await controller.start({ buildId: selectedBuild, device, osVersion, appearance }));
    } catch (error) {
        return errorResult(error);
    }
});

server.registerTool("ios_preview_screenshot", {
    description: "Capture the current simulator screen as an image."
}, async () => {
    try {
        const screenshot = await controller.invoke("screenshot");
        return { content: [{ type: "image", data: screenshot.data, mimeType: screenshot.mimeType }] };
    } catch (error) {
        return errorResult(error);
    }
});

server.registerTool("ios_preview_ui_tree", {
    description: "Read Appetize's current experimental accessibility UI tree for the simulator."
}, async () => {
    try {
        return textResult(await controller.invoke("uiTree"));
    } catch (error) {
        return errorResult(error);
    }
});

server.registerTool("ios_preview_tap", {
    description: "Tap an iOS accessibility element, or use coordinates only when no stable selector exists.",
    inputSchema: {
        selector: selectorSchema.optional(),
        x: z.number().min(0).max(10000).optional(),
        y: z.number().min(0).max(10000).optional()
    }
}, async ({ selector, x, y }) => {
    try {
        const target = selector ? { element: { attributes: selector } } : { coordinates: { x, y } };
        if (!selector && (x === undefined || y === undefined)) throw new Error("Provide a selector or both x and y coordinates.");
        return textResult(await controller.invoke("tap", target));
    } catch (error) {
        return errorResult(error);
    }
});

server.registerTool("ios_preview_swipe", {
    description: "Swipe the current simulator screen in one direction.",
    inputSchema: { gesture: z.enum(["up", "down", "left", "right"]) }
}, async ({ gesture }) => {
    try {
        return textResult(await controller.invoke("swipe", gesture));
    } catch (error) {
        return errorResult(error);
    }
});

server.registerTool("ios_preview_type", {
    description: "Type text into the active iOS control. This is limited to 1000 characters by the provider.",
    inputSchema: { text: z.string().min(1).max(1000) }
}, async ({ text }) => {
    try {
        return textResult(await controller.invoke("type", text));
    } catch (error) {
        return errorResult(error);
    }
});

server.registerTool("ios_preview_restart", {
    description: "Restart the currently running preview app, retaining only simulator-session state controlled by Appetize."
}, async () => {
    try {
        return textResult(await controller.invoke("restart"));
    } catch (error) {
        return errorResult(error);
    }
});

server.registerTool("ios_preview_end", {
    description: "End the active simulator session and close the local browser. Safe to call repeatedly."
}, async () => textResult(await controller.end()));

const transport = new StdioServerTransport();
await server.connect(transport);

async function shutdown() {
    await controller.end();
    process.exit(0);
}

process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
