import { readFile } from "node:fs/promises";
import { basename } from "node:path";

const endpoint = "https://api.appetize.io/v1/apps";

export async function uploadSimulatorArchive({ archivePath, apiToken, note }) {
    if (!apiToken) throw new Error("APPETIZE_API_TOKEN is not configured.");

    const file = await readFile(archivePath);
    const body = new FormData();
    body.append("file", new Blob([file], { type: "application/zip" }), basename(archivePath));
    body.append("platform", "ios");
    body.append("note", note);
    body.append("appPermissions.run", "public");

    const response = await fetch(endpoint, {
        method: "POST",
        headers: { "X-API-KEY": apiToken },
        body
    });
    const responseBody = await response.text();
    if (!response.ok) throw new Error(`Appetize upload failed with HTTP ${response.status}: ${responseBody.slice(0, 500)}`);

    let payload;
    try {
        payload = JSON.parse(responseBody);
    } catch {
        throw new Error("Appetize upload returned an invalid JSON response.");
    }
    const buildId = payload.publicKey || payload.buildId;
    if (!buildId) throw new Error("Appetize upload response did not contain a build identifier.");
    return { buildId, uploadedAt: new Date().toISOString() };
}
