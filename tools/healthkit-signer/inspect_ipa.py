"""Independent, fail-closed checks for this app's single arm64 executable."""
import argparse
import datetime as dt
import hashlib
from pathlib import Path, PurePosixPath
import plistlib
import re
import stat
import struct
import subprocess
import tempfile
import zipfile

HEALTH = "com.apple.developer.healthkit"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def archive_entries(archive):
    entries = archive.infolist()
    require(len(entries) <= 10000, "Too many ZIP entries")
    require(sum(x.file_size for x in entries) <= 512 * 1024 * 1024, "IPA too large")
    seen = set()
    for item in entries:
        path = PurePosixPath(item.filename)
        key = item.filename.rstrip("/").casefold()
        require(key not in seen, "Duplicate/case-colliding ZIP entry")
        seen.add(key)
        require(not path.is_absolute() and ".." not in path.parts and "\\" not in item.orig_filename,
                "Unsafe ZIP path")
        require(all(re.fullmatch(r"[^<>:\"|?*\x00-\x1f]+", p) and not p.endswith((".", " "))
                    and p.split(".")[0].upper() not in {"CON", "PRN", "AUX", "NUL", *(f"COM{i}" for i in range(10)), *(f"LPT{i}" for i in range(10))}
                    for p in path.parts), "Unsafe Windows ZIP path")
        mode = item.external_attr >> 16
        require(not stat.S_ISLNK(mode), "Symlinks are not supported")
    roots = {str(PurePosixPath(x.filename).parent) for x in entries
             if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", x.filename)}
    require(len(roots) == 1, "Expected exactly one main app")
    root = roots.pop()
    require(not any("/PlugIns/" in x.filename or "/Frameworks/" in x.filename for x in entries),
            "Extensions/frameworks require additional signing checks; not supported")
    return entries, root


def prepare(ipa, destination, bundle):
    require(not destination.exists(), "Working directory already exists")
    with zipfile.ZipFile(ipa) as archive:
        entries, root = archive_entries(archive)
        info = plistlib.loads(archive.read(root + "/Info.plist"))
        require(info.get("CFBundleIdentifier") == bundle, "Bundle ID mismatch; will not rewrite identity")
        executable = info.get("CFBundleExecutable", "")
        require(re.fullmatch(r"[A-Za-z0-9_.-]+", executable) and executable not in {".", ".."}, "Unsafe executable name")
        require(info.get("NSHealthShareUsageDescription"), "Health read usage description missing")
        destination.mkdir(parents=True)
        for item in entries:
            if item.filename.startswith(root + "/"):
                target = destination.joinpath(*PurePosixPath(item.filename).parts)
                if item.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with archive.open(item) as source, target.open("xb") as output:
                        import shutil
                        shutil.copyfileobj(source, output)
        return destination / root


def signature_blobs(binary):
    require(len(binary) >= 32 and binary[:4] == b"\xcf\xfa\xed\xfe", "Expected thin 64-bit Mach-O")
    require(struct.unpack_from("<I", binary, 4)[0] == 0x0100000C, "Expected arm64")
    count, size = struct.unpack_from("<II", binary, 16)
    require(count <= 10000 and 32 + size <= len(binary), "Invalid load-command table")
    offset, signature = 32, None
    for _ in range(count):
        require(offset + 8 <= 32 + size, "Truncated load command")
        command, length = struct.unpack_from("<II", binary, offset)
        require(length >= 8 and offset + length <= 32 + size, "Invalid load command")
        if command == 0x1D:
            require(length == 16 and signature is None, "Ambiguous signature")
            start, length_sig = struct.unpack_from("<II", binary, offset + 8)
            require(start >= 32 + size and start + length_sig <= len(binary), "Invalid signature bounds")
            signature = binary[start:start + length_sig]
        offset += length
    require(signature is not None and len(signature) >= 12, "Unsigned executable")
    magic, length, count = struct.unpack_from(">III", signature)
    require(magic == 0xFADE0CC0 and length <= len(signature) and 12 + count * 8 <= length, "Invalid signature superblob")
    blobs, ranges = {}, []
    for i in range(count):
        kind, offset = struct.unpack_from(">II", signature, 12 + i * 8)
        require(kind not in blobs and offset >= 12 + count * 8 and offset + 8 <= length, "Invalid signature slot")
        _, blob_size = struct.unpack_from(">II", signature, offset)
        require(blob_size >= 8 and offset + blob_size <= length, "Invalid blob bounds")
        require(all(offset + blob_size <= a or offset >= b for a, b in ranges), "Overlapping signature blobs")
        ranges.append((offset, offset + blob_size))
        blobs[kind] = signature[offset:offset + blob_size]
    require({0, 5, 0x10000} <= blobs.keys(), "CodeDirectory, XML entitlements or CMS signature missing")
    require(blobs[5][:4] == bytes.fromhex("fade7171"), "Invalid entitlement blob")
    require(blobs[0x10000][:4] == bytes.fromhex("fade0b01"), "Invalid CMS blob")
    return blobs


def check_profile(profile, entitlements, bundle, udid, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    allowed = profile.get("Entitlements", {})
    require(allowed.get(HEALTH) is True and entitlements.get(HEALTH) is True, "HealthKit missing or not a Boolean true")
    identity = allowed.get("application-identifier")
    require(isinstance(identity, str) and identity.endswith("." + bundle) and "*" not in identity,
            "Profile app identity mismatch")
    require(entitlements.get("application-identifier") == identity, "Signature app identity mismatch")
    team = allowed.get("com.apple.developer.team-identifier")
    require(isinstance(team, str) and team in profile.get("TeamIdentifier", []), "Profile team mismatch")
    require(entitlements.get("com.apple.developer.team-identifier") == team, "Signature team mismatch")
    require(udid in profile.get("ProvisionedDevices", []), "iPhone absent from profile")
    expiry = profile.get("ExpirationDate")
    require(isinstance(expiry, dt.datetime) and expiry.replace(tzinfo=dt.timezone.utc) > now + dt.timedelta(minutes=5), "Profile expired or expires too soon")
    for key, value in entitlements.items():
        require(key in allowed and value == allowed[key], "Unexpected or broadened signed entitlement: " + key)
    return expiry


def check_code(binary, blobs, info, resources):
    cd = blobs[0]
    require(len(cd) >= 44 and cd[:4] == bytes.fromhex("fade0c02"), "Invalid CodeDirectory")
    hash_offset, _, specials, slots, limit = struct.unpack_from(">IIIII", cd, 16)
    hash_size, hash_type, _, page_power = struct.unpack_from("4B", cd, 36)
    algorithms = {1: (hashlib.sha1, 20), 2: (hashlib.sha256, 32), 3: (hashlib.sha256, 20)}
    require(hash_type in algorithms and page_power in range(12, 17), "Unsupported CodeDirectory hash/page format")
    algorithm, expected_size = algorithms[hash_type]
    require(hash_size == expected_size and 0 < limit <= len(binary), "Invalid code limits")
    require(hash_offset - specials * hash_size >= 44 and hash_offset + slots * hash_size <= len(cd), "Invalid hash table")
    page = 1 << page_power
    require(slots == (limit + page - 1) // page, "Code slot count mismatch")
    for i in range(slots):
        expected = cd[hash_offset + i * hash_size:hash_offset + (i + 1) * hash_size]
        require(algorithm(binary[i * page:min((i + 1) * page, limit)]).digest()[:hash_size] == expected, "Executable page hash mismatch")
    for slot, data in [(1, info), (3, resources), (5, blobs[5])]:
        require(specials >= slot, "Required special hash slot missing")
        expected = cd[hash_offset - slot * hash_size:hash_offset - (slot - 1) * hash_size]
        require(algorithm(data).digest()[:hash_size] == expected, "Signed metadata hash mismatch")


def openssl_run(executable, args):
    result = subprocess.run([str(executable), *map(str, args)], capture_output=True, timeout=30)
    require(result.returncode == 0, "OpenSSL signature/trust validation failed")
    return result.stdout


def inspect(app, bundle, udid, openssl, roots):
    raw_info = (app / "Info.plist").read_bytes()
    info = plistlib.loads(raw_info)
    require(info.get("CFBundleIdentifier") == bundle, "Final app identifier mismatch")
    exe = info.get("CFBundleExecutable", "")
    require(re.fullmatch(r"[A-Za-z0-9_.-]+", exe) and exe not in {".", ".."}, "Unsafe executable name")
    binary = (app / exe).read_bytes()
    blobs = signature_blobs(binary)
    with tempfile.TemporaryDirectory(prefix="lidllean-verify-") as temp:
        work = Path(temp)
        profile_xml, signer = work / "profile.plist", work / "profile-signer.pem"
        openssl_run(openssl, ["cms", "-verify", "-binary", "-inform", "DER", "-in", app / "embedded.mobileprovision",
            "-CAfile", roots, "-purpose", "any", "-out", profile_xml, "-signer", signer])
        subject = openssl_run(openssl, ["x509", "-in", signer, "-noout", "-subject", "-nameopt", "RFC2253"]).decode()
        require("CN=Apple iPhone OS Provisioning Profile Signing" in subject, "Unexpected profile signing authority")
        profile = plistlib.loads(profile_xml.read_bytes())
        entitlements = plistlib.loads(blobs[5][8:])
        expiry = check_profile(profile, entitlements, bundle, udid)
        check_code(binary, blobs, raw_info, (app / "_CodeSignature/CodeResources").read_bytes())
        cms, directory, app_signer = work / "signature.der", work / "directory.bin", work / "developer.pem"
        cms.write_bytes(blobs[0x10000][8:])
        directory.write_bytes(blobs[0])
        # Apple profile trust was verified above. Bind this signature to its authorized developer cert.
        openssl_run(openssl, ["cms", "-verify", "-binary", "-inform", "DER", "-in", cms,
            "-content", directory, "-noverify", "-out", work / "verified.bin", "-signer", app_signer])
        developer = openssl_run(openssl, ["x509", "-in", app_signer, "-outform", "DER"])
        require(developer in profile.get("DeveloperCertificates", []), "Signing certificate not authorized by Apple profile")
    return {"bundle": bundle, "expires": expiry.isoformat(), "healthkit": True}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", type=Path)
    parser.add_argument("--destination", type=Path)
    parser.add_argument("--app", type=Path)
    parser.add_argument("--bundle-id", default="com.alial.lidllean")
    parser.add_argument("--udid")
    parser.add_argument("--openssl", type=Path)
    parser.add_argument("--roots", type=Path)
    args = parser.parse_args()
    try:
        if args.prepare:
            print(prepare(args.prepare, args.destination, args.bundle_id))
        else:
            print(inspect(args.app, args.bundle_id, args.udid, args.openssl, args.roots))
    except Exception as error:
        parser.exit(1, f"STOP: {error}\n")
