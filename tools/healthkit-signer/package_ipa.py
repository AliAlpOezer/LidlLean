from pathlib import Path
import sys
import zipfile

root, output = map(Path, sys.argv[1:])
with zipfile.ZipFile(output, "x", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted((root / "Payload").rglob("*")):
        if path.is_file():
            archive.write(path, path.relative_to(root).as_posix())
with zipfile.ZipFile(output) as archive:
    if archive.testzip() is not None:
        raise ValueError("Packaged IPA failed CRC verification")
