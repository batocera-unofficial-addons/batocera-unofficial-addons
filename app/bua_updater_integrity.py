"""Verify a BUA updater installation against trusted package metadata."""

import hashlib
import json
from pathlib import Path, PurePosixPath


RUNTIME_FILES = {
    "catalog/global/global-update-manifest.json",
    "catalog/global/global-update-manifest.csv",
    "catalog/global/global-update-summary.txt",
    "catalog/global/catalog-apps-fingerprint.txt",
}

RUNTIME_PREFIXES = (
    "catalog/global/installer-cache/",
)


def verify_updater_installation(
    updater_dir,
    integrity_manifest,
    compatibility_contract,
    frontend_api_version=1,
):
    """Return (verified, reason), without changing installation files."""
    root = Path(updater_dir)
    manifest = json.loads(Path(integrity_manifest).read_text())
    contract = json.loads(Path(compatibility_contract).read_text())

    if not root.is_dir() or root.is_symlink():
        return False, "Updater directory missing or invalid"

    if manifest.get("backend_api_version") not in (
        contract.get("supported_frontend_api_versions") or []
    ):
        return False, "Backend compatibility mismatch"

    if frontend_api_version != contract.get("backend_api_version"):
        return False, "Frontend compatibility mismatch"

    files = manifest.get("file_hashes")
    if not isinstance(files, dict) or not files:
        return False, "Invalid file-integrity manifest"

    immutable = {
        name: digest
        for name, digest in files.items()
        if name not in RUNTIME_FILES
        and not name.startswith(RUNTIME_PREFIXES)
    }

    required = contract.get("required_files", [])
    if not all(name in immutable for name in required):
        return False, "Required program files missing from manifest"

    for relative, digest in immutable.items():
        if not isinstance(relative, str):
            return False, "Invalid manifest file path"

        path = PurePosixPath(relative)

        if (
            not relative
            or path.is_absolute()
            or ".." in path.parts
            or "." in path.parts
            or "\\" in relative
            or relative.startswith("/")
            or relative != path.as_posix()
        ):
            return False, f"Unsafe manifest file path: {relative}"

        if (
            not isinstance(digest, str)
            or len(digest) != 64
            or any(ch not in "0123456789abcdef" for ch in digest)
        ):
            return False, f"Invalid SHA256: {relative}"

        candidate = root
        for part in path.parts:
            candidate = candidate / part
            if candidate.is_symlink():
                return False, f"Symlink in updater path: {relative}"

        if not candidate.is_file():
            return False, f"Missing or invalid file: {relative}"

        actual = hashlib.sha256(candidate.read_bytes()).hexdigest()
        if actual != digest:
            return False, f"File-integrity mismatch: {relative}"

    return True, "Verified compatible updater"
