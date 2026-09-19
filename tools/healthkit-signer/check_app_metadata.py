"""Check the built product, not the source plist that XcodeGen replaces."""
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    info = plistlib.loads(archive.read("Payload/LidlLean.app/Info.plist"))
for key in ("NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription", "NSCameraUsageDescription"):
    if not isinstance(info.get(key), str) or not info[key].strip():
        raise SystemExit("Missing built privacy description: " + key)
schemes = [scheme for entry in info.get("CFBundleURLTypes", []) for scheme in entry.get("CFBundleURLSchemes", [])]
if "lidllean" not in schemes:
    raise SystemExit("Built app lost its local Health Shortcut URL scheme")
print("PASS: built Health/camera descriptions and local import scheme are present")
