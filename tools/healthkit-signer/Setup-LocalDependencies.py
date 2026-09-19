"""Fetch public Apple roots; extract local arm64 ADI from a user-supplied Apple Music APK."""
import argparse
import base64
import hashlib
from pathlib import Path
import urllib.request
import urllib.parse
import tempfile
import zipfile

APPLE_MUSIC = "https://apps.mzstatic.com/content/android-apple-music-apk/applemusic.apk"
ROOTS = [
    "https://www.apple.com/appleca/AppleIncRootCertificate.cer",
    "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer",
    "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
]


def setup(apk, destination, roots_output):
    destination.mkdir(parents=True, exist_ok=True)
    for name in ("libCoreADI.so", "libstoreservicescore.so"):
        with zipfile.ZipFile(apk) as archive:
            item = archive.getinfo("lib/arm64-v8a/" + name)
            if item.file_size > 64 * 1024 * 1024:
                raise ValueError("Unexpected ADI library size")
            data = archive.read(item)
        if data[:5] != b"\x7fELF\x02" or int.from_bytes(data[18:20], "little") != 183:
            raise ValueError("Expected an arm64 ELF library")
        (destination / name).write_bytes(data)
        print(name, hashlib.sha256(data).hexdigest())
    pem = bytearray()
    for url in ROOTS:
        with urllib.request.urlopen(url, timeout=30) as response:
            if not response.url.startswith("https://www.apple.com/"):
                raise ValueError("Unexpected certificate download origin")
            data = response.read(65537)
        if len(data) > 65536 or not data.startswith(b"\x30"):
            raise ValueError("Invalid certificate download")
        pem.extend(b"-----BEGIN CERTIFICATE-----\n" + base64.encodebytes(data) + b"-----END CERTIFICATE-----\n")
    roots_output.write_bytes(pem)
    print("Local libraries prepared. No Apple login was used. APK authenticity remains your responsibility.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--apple-music-apk", type=Path)
    source.add_argument("--download-from-apple", action="store_true")
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--roots-output", type=Path, default=Path(__file__).with_name("apple-roots.pem"))
    args = parser.parse_args()
    if args.download_from_apple:
        print("Downloading Apple Music from Apple's CDN for local ADI extraction; no login required.")
        with tempfile.TemporaryDirectory(prefix="lidllean-adi-") as temp:
            apk = Path(temp) / "applemusic.apk"
            with urllib.request.urlopen(APPLE_MUSIC, timeout=60) as response, apk.open("wb") as output:
                final = urllib.parse.urlparse(response.url)
                if final.scheme != "https" or final.hostname != "apps.mzstatic.com":
                    raise ValueError("Unexpected APK download origin; refusing mirror")
                total = 0
                while chunk := response.read(1024 * 1024):
                    total += len(chunk)
                    if total > 256 * 1024 * 1024:
                        raise ValueError("Unexpected APK download size")
                    output.write(chunk)
            setup(apk, args.destination, args.roots_output)
    else:
        setup(args.apple_music_apk, args.destination, args.roots_output)
