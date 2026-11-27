"""Verify the exact public update payload before it leaves the hosted runner."""

import base64
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

ASSET = "CaseVector-Windows-x64.zip"
KEY_ID = "2026-11b"
# Existing client trust anchor. A different private key cannot publish an update.
PUBLIC_KEY = "UuVeLNLUL5D3lxHg4qN57zq4/IMsnJ8jx1r6dWf9rhM="
EXPECTED = {ASSET, ASSET + ".sha256", "release-manifest.json", "release-manifest.sig", "release-notes.md", "CaseVector"}
FORBIDDEN = {".db", ".sqlite", ".sqlite3", ".xlsx", ".xls", ".csv", ".py", ".pyc", ".pyo", ".env"}


def verify(folder: Path, tag: str) -> None:
    if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Invalid release tag")
    if {entry.name for entry in folder.iterdir()} != EXPECTED:
        raise ValueError("Unexpected release directory contents")
    raw = (folder / "release-manifest.json").read_bytes()
    signature = base64.b64decode((folder / "release-manifest.sig").read_bytes().strip(), validate=True)
    Ed25519PublicKey.from_public_bytes(base64.b64decode(PUBLIC_KEY)).verify(signature, raw)
    manifest = json.loads(raw)
    archive = folder / ASSET
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    package = manifest["package"]
    if (manifest["application"] != "CaseVector" or manifest["version"] != tag[1:]
            or manifest["key_id"] != KEY_ID or package["name"] != ASSET
            or package["architecture"] != "windows-x64"
            or package["size"] != archive.stat().st_size or package["sha256"] != digest):
        raise ValueError("Signed manifest does not match the package")
    if (folder / (ASSET + ".sha256")).read_text(encoding="ascii") != f"{digest}  {ASSET}\n":
        raise ValueError("Checksum sidecar does not match")
    with zipfile.ZipFile(archive) as payload:
        members = payload.namelist()
        if not payload.testzip() is None:
            raise ValueError("ZIP contains a corrupt member")
        if "CaseVector/CaseVector.exe" not in members:
            raise ValueError("Application executable is missing")
        if "CaseVector/_internal/CaseVectorUpdater.exe" not in members:
            raise ValueError("Updater executable is missing")
        if any(Path(name).suffix.lower() in FORBIDDEN or ".git/" in name or "__pycache__/" in name
               for name in members):
            raise ValueError("Source or user data found in ZIP")
        for name in ("bundle.json", "installation.json"):
            metadata = json.loads(payload.read("CaseVector/" + name))
            if metadata.get("version") != tag[1:]:
                raise ValueError("Bundle version disagrees with tag")


if __name__ == "__main__":
    try:
        verify(Path(sys.argv[1]), sys.argv[2])
    except Exception:
        raise SystemExit("Release package verification failed")
    print("Signed release package verified")
