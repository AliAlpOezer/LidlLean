"""Apply the reviewed overlay to an exact, clean upstream checkout."""
from pathlib import Path
import argparse
import shutil
import subprocess

REVISION = "10b446fc6fc47fe81b60879dfb126d0c8098ec29"


def replace_once(root, relative, old, new):
    path = root / relative
    text = path.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise RuntimeError(f"Source drift in {relative}; refusing ambiguous patch")
    path.write_text(text.replace(old, new), encoding="utf-8", newline="\n")


def prepare(root):
    revision = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    if revision != REVISION:
        raise RuntimeError("Wrong SideSign revision")
    if subprocess.check_output(["git", "-C", str(root), "status", "--porcelain"], text=True).strip():
        raise RuntimeError("Upstream checkout must be clean; refusing to overwrite edits")
    replace_once(root, "CLI/CommandHandler.swift", "private static func fetchAnisetteHeaders", "static func fetchAnisetteHeaders")
    replace_once(root, "Sources/Logging.swift", "public func debugLog(_ text: @autoclosure () -> String) {",
                 "public func debugLog(_ text: @autoclosure () -> String) {\n    guard SideSignLogging.isLoggingEnabled else { return }")
    replace_once(root, "CLI/SecureInput.swift", "        let input = readLine(strippingNewline: true)\n        if emptyLineAfter { print() }\n        return input",
                 "        return nil // Refuse redirected/non-private password input.")
    replace_once(root, "Sources/CodeSigning/CodeSignerAPI.swift", '                          key != "get-task-allow" ',
                 '                          key != "get-task-allow" &&\n                          key != "com.apple.developer.healthkit" ')
    shutil.copyfile(Path(__file__).with_name("main.swift"), root / "CLI/main.swift")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    prepare(parser.parse_args().source.resolve())
    print("Applied LidlLean overlay; upstream lockfile unchanged.")
