import copy
import datetime as dt
import io
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

from inspect_ipa import HEALTH, archive_entries, check_profile, prepare, signature_blobs, der_entitlements


class DERTests(unittest.TestCase):
    def test_boolean_dictionary(self):
        self.assertEqual(der_entitlements(bytes.fromhex("310830060c01780101ff")), {"x": True})
        self.assertEqual(der_entitlements(bytes.fromhex("310830060c0178010101")), {"x": True})

    def test_integer_is_not_boolean(self):
        self.assertIs(type(der_entitlements(bytes.fromhex("310830060c0178020101"))["x"]), int)

    def test_truncated_or_indefinite(self):
        for data in [b"", b"\x31\x80", b"\x31\x03\x01\x01", b"\x31\0garbage"]:
            with self.assertRaises(ValueError): der_entitlements(data)

    def test_duplicate_keys(self):
        with self.assertRaises(ValueError): der_entitlements(bytes.fromhex("311030060c017801010130060c0178010100"))


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.entitlements = {HEALTH: True, "application-identifier": "TEAM123456.com.alial.lidllean",
                             "com.apple.developer.team-identifier": "TEAM123456"}
        self.profile = {"Entitlements": copy.deepcopy(self.entitlements), "TeamIdentifier": ["TEAM123456"],
                        "ProvisionedDevices": ["phone"], "ExpirationDate": dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=7)}

    def check(self):
        return check_profile(self.profile, self.entitlements, "com.alial.lidllean", "phone")

    def test_matching_profile(self):
        self.assertIsInstance(self.check(), dt.datetime)

    def test_missing_or_false_healthkit(self):
        for value in [None, False, 1, "true"]:
            with self.subTest(value=value):
                self.profile["Entitlements"][HEALTH] = value
                with self.assertRaises(ValueError): self.check()

    def test_signature_missing_healthkit(self):
        self.entitlements.pop(HEALTH)
        with self.assertRaises(ValueError): self.check()

    def test_expiry(self):
        self.profile["ExpirationDate"] = dt.datetime.now(dt.timezone.utc)
        with self.assertRaises(ValueError): self.check()

    def test_other_phone(self):
        self.profile["ProvisionedDevices"] = ["other"]
        with self.assertRaises(ValueError): self.check()

    def test_other_team(self):
        self.profile["TeamIdentifier"] = ["OTHER"]
        with self.assertRaises(ValueError): self.check()

    def test_wildcard(self):
        self.profile["Entitlements"]["application-identifier"] = "TEAM123456.*"
        with self.assertRaises(ValueError): self.check()

    def test_other_app(self):
        self.entitlements["application-identifier"] = "TEAM123456.com.other.app"
        with self.assertRaises(ValueError): self.check()

    def test_extra_entitlement(self):
        self.entitlements["task_for_pid-allow"] = True
        with self.assertRaises(ValueError): self.check()


class ArchiveTests(unittest.TestCase):
    def make_zip(self, extra):
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w") as archive:
            archive.writestr("Payload/LidlLean.app/Info.plist", plistlib.dumps({"CFBundleIdentifier": "com.alial.lidllean",
                "CFBundleExecutable": "LidlLean", "NSHealthShareUsageDescription": "Read activity"}))
            archive.writestr("Payload/LidlLean.app/LidlLean", b"unsigned")
            for name, content in extra:
                if isinstance(name, str) and "\\" in name:
                    raw = zipfile.ZipInfo()
                    raw.filename = name
                    name = raw
                archive.writestr(name, content)
        output.seek(0)
        return output

    def test_unsafe_paths(self):
        for path in ["../secret", "/absolute", "C:/secret", "Payload\\secret", "Payload/NUL.txt", "Payload/foo.", "Payload/foo:bar"]:
            with self.subTest(path=path), zipfile.ZipFile(self.make_zip([(path, b"x")])) as archive:
                with self.assertRaises(ValueError): archive_entries(archive)

    def test_case_collision(self):
        with zipfile.ZipFile(self.make_zip([("payload/lidllean.app/lidllean", b"x")])) as archive:
            with self.assertRaises(ValueError): archive_entries(archive)

    def test_symlink(self):
        entry = zipfile.ZipInfo("Payload/LidlLean.app/link")
        entry.create_system = 3
        entry.external_attr = 0o120777 << 16
        with zipfile.ZipFile(self.make_zip([(entry, b"outside")])) as archive:
            with self.assertRaises(ValueError): archive_entries(archive)

    def test_extensions(self):
        with zipfile.ZipFile(self.make_zip([("Payload/LidlLean.app/PlugIns/foo", b"x")])) as archive:
            with self.assertRaises(ValueError): archive_entries(archive)

    def test_prepare_preserves_original(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            ipa = root / "source.ipa"
            original = self.make_zip([]).getvalue()
            ipa.write_bytes(original)
            app = prepare(ipa, root / "work", "com.alial.lidllean")
            self.assertEqual((app / "LidlLean").read_bytes(), b"unsigned")
            self.assertEqual(ipa.read_bytes(), original)
            with self.assertRaises(ValueError): prepare(ipa, root / "work", "com.alial.lidllean")
            with self.assertRaises(ValueError): prepare(ipa, root / "other", "com.other.app")

    def test_unsigned_and_malformed_macho(self):
        for binary in [b"", b"unsigned", b"\xcf\xfa\xed\xfe" + bytes(28),
                       struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 1, 8, 0, 0) + struct.pack("<II", 0x1D, 0)]:
            with self.subTest(binary=binary):
                with self.assertRaises(ValueError): signature_blobs(binary)


if __name__ == "__main__":
    unittest.main()
