import { access, stat } from "node:fs/promises";
import { constants } from "node:fs";
import { fileURLToPath } from "node:url";
import { basename, extname, isAbsolute, relative, resolve } from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const toolDirectory = resolve(fileURLToPath(new URL("..", import.meta.url)));
export const defaultArtifactDirectory = resolve(toolDirectory, "../../preview-artifacts");
const maximumArchiveBytes = 500 * 1024 * 1024;

export function previewArtifactDirectory(environment = process.env) {
    return resolve(environment.IOS_PREVIEW_ARTIFACT_DIR || defaultArtifactDirectory);
}

export function resolveSimulatorArchive(inputPath, artifactDirectory = previewArtifactDirectory()) {
    const allowedDirectory = resolve(artifactDirectory);
    const archivePath = resolve(inputPath);
    const relation = relative(allowedDirectory, archivePath);

    if (relation === "" || relation.startsWith("..") || isAbsolute(relation)) {
        throw new Error(`Archive must be inside ${allowedDirectory}.`);
    }
    if (extname(archivePath).toLowerCase() !== ".zip") {
        throw new Error("Simulator archive must use the .zip extension.");
    }
    return archivePath;
}

export async function assertSimulatorArchive(archivePath) {
    await access(archivePath, constants.R_OK);
    const details = await stat(archivePath);
    if (!details.isFile()) throw new Error("Simulator archive path is not a file.");
    if (details.size === 0) throw new Error("Simulator archive is empty.");
    if (details.size > maximumArchiveBytes) throw new Error("Simulator archive exceeds the 500 MB preview limit.");

    let listing;
    try {
        ({ stdout: listing } = await execFileAsync("tar", ["-tf", archivePath], { maxBuffer: 10 * 1024 * 1024 }));
    } catch {
        throw new Error("Simulator archive could not be read as a ZIP file.");
    }

    const entries = listing.split(/\r?\n/).filter(Boolean);
    if (!entries.some((entry) => /(^|\/)\.app\/Info\.plist$/i.test(entry))) {
        throw new Error("Simulator archive must contain an iOS .app bundle with Info.plist.");
    }
    return { archivePath, filename: basename(archivePath), size: details.size };
}
