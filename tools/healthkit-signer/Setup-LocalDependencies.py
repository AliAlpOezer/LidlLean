"""Fetch public Apple roots; extract local arm64 ADI from a user-supplied Apple Music APK."""
import argparse
import base64
import hashlib
from pathlib import Path
import urllib.request
import zipfile

ROOTS = [
    "https://www.apple.com/appleca/AppleIncRootCertificate.cer",
    "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer",
    "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
]


def setup(apk, destination):
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
    Path(__file__).with_name("apple-roots.pem").write_bytes(pem)
    print("Local libraries prepared. No Apple login was used. APK authenticity remains your responsibility.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apple-music-apk", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    setup(args.apple_music_apk, args.destination)
