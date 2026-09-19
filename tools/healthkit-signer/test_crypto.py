"""Synthetic CMS fixtures exercise the whole independent verifier without Apple login."""
import datetime as dt
import hashlib
from pathlib import Path
import plistlib
import shutil
import struct
import subprocess
import tempfile
import unittest

from inspect_ipa import HEALTH, inspect

OPENSSL = shutil.which("openssl") or ("C:/Program Files/Git/usr/bin/openssl.exe" if Path("C:/Program Files/Git/usr/bin/openssl.exe").exists() else None)


def blob(magic, content):
    return struct.pack(">II", magic, len(content) + 8) + content


@unittest.skipUnless(OPENSSL, "OpenSSL required for cryptographic integration tests")
class CryptoTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="healthkit-test-")
        cls.root = Path(cls.temp.name)
        cls.cert = cls.root / "root.pem"
        cls.key = cls.root / "root.key"
        cls.command("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                    "-subj", "/CN=Apple iPhone OS Provisioning Profile Signing", "-keyout", cls.key, "-out", cls.cert)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    @classmethod
    def command(cls, *args):
        result = subprocess.run([OPENSSL, *map(str, args)], capture_output=True, timeout=30)
        if result.returncode:
            raise RuntimeError(result.stderr.decode(errors="replace"))
        return result.stdout

    def signed(self, data, attached=False):
        source, target = self.root / "input", self.root / "cms"
        source.write_bytes(data)
        self.command("cms", "-sign", "-binary", "-in", source, "-signer", self.cert,
                     "-inkey", self.key, "-outform", "DER", "-out", target, "-md", "sha256",
                     *(["-nodetach"] if attached else []))
        return target.read_bytes()

    def setUp(self):
        self.app = self.root / "LidlLean.app"
        self.app.mkdir(exist_ok=True)
        (self.app / "_CodeSignature").mkdir(exist_ok=True)
        self.entitlements = {HEALTH: True, "application-identifier": "TEAM123456.com.alial.lidllean",
                             "com.apple.developer.team-identifier": "TEAM123456"}
        developer = self.command("x509", "-in", self.cert, "-outform", "DER")
        self.profile = {"Entitlements": self.entitlements, "TeamIdentifier": ["TEAM123456"],
                        "ProvisionedDevices": ["phone"], "DeveloperCertificates": [developer],
                        "ExpirationDate": dt.datetime.now(dt.timezone.utc).replace(tzinfo=None) + dt.timedelta(hours=12)}
        self.write_profile()
        info = plistlib.dumps({"CFBundleIdentifier": "com.alial.lidllean", "CFBundleExecutable": "LidlLean"})
        resources = plistlib.dumps({"files2": {}})
        (self.app / "Info.plist").write_bytes(info)
        (self.app / "_CodeSignature/CodeResources").write_bytes(resources)
        ent_blob = blob(0xFADE7171, plistlib.dumps(self.entitlements))

        def directory(binary):
            hashes = bytearray(32 * 5)
            for slot, data in [(1, info), (3, resources), (5, ent_blob)]:
                hashes[(5-slot)*32:(6-slot)*32] = hashlib.sha256(data).digest()
            # Minimal CodeDirectory header, five special slots, one executable page.
            return struct.pack(">9I4BI", 0xFADE0C02, 44 + 192, 0x20001, 0, 44 + 160,
                               0, 5, 1, 4096, 32, 2, 0, 12, 0) + hashes + hashlib.sha256(binary).digest()

        def superblob(binary):
            cd = directory(binary)
            parts = [(0, cd), (5, ent_blob), (0x10000, blob(0xFADE0B01, self.signed(cd)))]
            offset = 12 + 8 * len(parts)
            indexes, content = b"", b""
            for kind, part in parts:
                indexes += struct.pack(">II", kind, offset)
                content += part
                offset += len(part)
            return struct.pack(">III", 0xFADE0CC0, offset, len(parts)) + indexes + content

        size = len(superblob(bytes(4096)))
        binary = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 1, 16, 0, 0)
        binary += struct.pack("<4I", 0x1D, 16, 4096, size)
        binary = binary.ljust(4096, b"\0")
        signature = superblob(binary)
        self.assertEqual(size, len(signature))
        (self.app / "LidlLean").write_bytes(binary + signature)

    def write_profile(self):
        (self.app / "embedded.mobileprovision").write_bytes(self.signed(plistlib.dumps(self.profile), attached=True))

    def verify(self, roots=None):
        return inspect(self.app, "com.alial.lidllean", "phone", OPENSSL, roots or self.cert)

    def test_full_chain_and_signature(self):
        self.assertTrue(self.verify()["healthkit"])

    def test_modified_executable(self):
        path = self.app / "LidlLean"
        data = bytearray(path.read_bytes())
        data[100] ^= 1
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "page hash"): self.verify()

    def test_unauthorized_developer_certificate(self):
        self.profile["DeveloperCertificates"] = []
        self.write_profile()
        with self.assertRaisesRegex(ValueError, "certificate not authorized"): self.verify()

    def test_profile_missing_healthkit(self):
        self.profile["Entitlements"].pop(HEALTH)
        self.write_profile()
        with self.assertRaisesRegex(ValueError, "HealthKit"): self.verify()

    def test_tampered_profile_cms(self):
        path = self.app / "embedded.mobileprovision"
        data = bytearray(path.read_bytes())
        data[-10] ^= 1
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "trust validation"): self.verify()


if __name__ == "__main__":
    unittest.main()
