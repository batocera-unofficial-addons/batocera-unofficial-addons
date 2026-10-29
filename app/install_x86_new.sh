#!/bin/bash
# BUA_SECURITY_EXTRACT_V1: strict staged extraction; links and traversal rejected.

# URLs
SCRIPT_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/app/symlinks.sh"
BATOCERA_ADDONS_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/BUA.sh"
UPDATER_SUPPORT_URL="https://raw.githubusercontent.com/klova5/batocera-unofficial-addons/feature/global-parent-source-updater/app/bua-updater-support-x86_64.tar.gz"
UPDATER_SUPPORT_SHA256="c8f11750bcf6534df8a44c22f6487ee8ab207b6798ac5f3efa2a9aae44eb05e5"
UPDATER_ROOT="/userdata/system/add-ons/bua/updater"

# Authenticated updater verification metadata.
UPDATER_VERIFICATION_URL="https://raw.githubusercontent.com/klova5/batocera-unofficial-addons/feature/global-parent-source-updater/app/bua-updater-verification-x86_64.tar.gz"
UPDATER_VERIFICATION_SHA256="435cb39fe5b62cf97a39ab9d17852dc1dd5611c93d826661d91a2e958f448249"
UPDATER_VERIFICATION_ROOT="/userdata/system/add-ons/bua/verification"
BATOCERA_ADDONS_LOGO_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/extra/batocera-unofficial-addons.png"
BATOCERA_ADDONS_WHEEL_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/extra/batocera-unofficial-addons-wheel.png"
XMLSTARLET_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/xmlstarlet"
ICON_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/extra/icon.png"
BUA_CLI_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/bua_cli.py"

# Paths
DOWNLOAD_DIR="/userdata/system/services"
SCRIPT_NAME="symlink_manager.sh"
SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

ROM_PORTS_DIR="/userdata/roms/ports"
BATOCERA_ADDONS_PATH="$ROM_PORTS_DIR/bua.sh"

XMLSTARLET_DEST="/userdata/system/add-ons/.dep/xmlstarlet"
BUA_CLI_DEST="/userdata/system/add-ons/bua/bin/bua"

APPNAME="BUA"
APPNAME_LC="${APPNAME,,}"

DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME_LC}/${APPNAME}.desktop"
RESTORE_SCRIPT="/userdata/system/configs/${APPNAME_LC}/restore_desktop_entry.sh"
CUSTOM_STARTUP="/userdata/system/custom.sh"

PORTS_IMAGES_DIR="/userdata/roms/ports/images"
BATOCERA_ADDONS_LOGO_DEST="${PORTS_IMAGES_DIR}/BatoceraUnofficialAddons.png"
BATOCERA_ADDONS_WHEEL_DEST="${PORTS_IMAGES_DIR}/BatoceraUnofficialAddons_Wheel.png"
GAMELIST_XML="${ROM_PORTS_DIR}/gamelist.xml"

# Ensure directories exist
mkdir -p "$DOWNLOAD_DIR" \
         "/userdata/system/add-ons" \
         "/userdata/system/add-ons/${APPNAME_LC}/extra" \
         "/userdata/system/configs/${APPNAME_LC}" \
         "$PORTS_IMAGES_DIR" \
         "$ROM_PORTS_DIR"

# Make sure custom.sh exists to keep grep happy under -euo
touch "$CUSTOM_STARTUP"

echo "Downloading the symlink manager script from $SCRIPT_URL..."
curl -fLs -o "$SCRIPT_PATH" "$SCRIPT_URL"

if [ ! -s "$SCRIPT_PATH" ]; then
    echo "Failed to download the symlink manager script. Exiting."
    exit 1
fi

# Download base dependencies
curl -fLs https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/app/dep.sh | bash

# Remove .sh extension and make executable
SCRIPT_WITHOUT_EXTENSION="${SCRIPT_PATH%.sh}"
mv "$SCRIPT_PATH" "$SCRIPT_WITHOUT_EXTENSION"
chmod +x "$SCRIPT_WITHOUT_EXTENSION"

echo "Enabling batocera-unofficial-addons-symlinks service..."
batocera-services enable symlink_manager

echo "Starting batocera-unofficial-addons-symlinks service..."
batocera-services start symlink_manager &>/dev/null &

echo "Downloading Batocera Unofficial Add-Ons Launcher from $BATOCERA_ADDONS_URL..."
wget --show-progress -O "$BATOCERA_ADDONS_PATH" "$BATOCERA_ADDONS_URL"

if [ ! -s "$BATOCERA_ADDONS_PATH" ]; then
    echo "Failed to download batocera-unofficial-addons launcher. Exiting."
    exit 1
fi

chmod +x "$BATOCERA_ADDONS_PATH"

# Install global parent-source updater support.
# Serialize with the Python startup installer.
mkdir -p "/userdata/system/add-ons/bua"

exec 9>"/userdata/system/add-ons/bua/.bua-support-install.lock"
if ! flock -x 9; then
    echo "Failed to acquire BUA updater installation lock."
    exit 1
fi

echo "Installing BUA global updater support..."

UPDATER_TMP="/tmp/bua-updater-support-x86_64.tar.gz"

rm -f "$UPDATER_TMP"

curl -fLs \
  -o "$UPDATER_TMP" \
  "$UPDATER_SUPPORT_URL"

if [ ! -s "$UPDATER_TMP" ]; then
    echo "Failed to download BUA updater support package. Exiting."
    exit 1
fi

DOWNLOADED_UPDATER_SHA256="$(sha256sum "$UPDATER_TMP" | awk '{print $1}')"

if [ "$DOWNLOADED_UPDATER_SHA256" != "$UPDATER_SUPPORT_SHA256" ]; then
    echo "BUA updater support checksum verification failed."
    echo "Expected: $UPDATER_SUPPORT_SHA256"
    echo "Actual:   $DOWNLOADED_UPDATER_SHA256"
    rm -f "$UPDATER_TMP"
    exit 1
fi

echo "BUA updater support checksum verified."

# Stage and verify the new updater before touching the active version.
UPDATER_BASE="/userdata/system/add-ons/bua"
mkdir -p "$UPDATER_BASE"

UPDATER_STAGE="$(mktemp -d "$UPDATER_BASE/.bua-installer-stage.XXXXXX")" || exit 1
UPDATER_PREVIOUS="$UPDATER_BASE/.bua-updater-previous"
UPDATER_BACKUPS="$UPDATER_BASE/.bua-updater-backups"

if ! python3 -c '#!/usr/bin/env python3
"""BUA archive extraction guard. Deliberately rejects links, special files and duplicate paths."""
import os
import stat
import sys
import tarfile
import zipfile
from pathlib import Path, PurePosixPath

MAX_MEMBERS = 100000
MAX_TOTAL_SIZE = 20 * 1024**3

def checked_name(name):
    if not isinstance(name, str) or not name or '"'"'\\'"'"' in name or '"'"'\x00'"'"' in name:
        raise ValueError(f'"'"'Unsafe archive name: {name!r}'"'"')
    if name.startswith('"'"'/'"'"') or name.startswith('"'"'//'"'"'):
        raise ValueError(f'"'"'Absolute archive path: {name!r}'"'"')
    parts = name.rstrip('"'"'/'"'"').split('"'"'/'"'"')
    if parts and parts[0] == '"'"'.'"'"':
        parts = parts[1:]
    if not parts or any(x in ('"'"''"'"', '"'"'.'"'"', '"'"'..'"'"') for x in parts):
        raise ValueError(f'"'"'Traversal or noncanonical path: {name!r}'"'"')
    if '"'"':'"'"' in parts[0]:
        raise ValueError(f'"'"'Drive-like archive path: {name!r}'"'"')
    return tuple(parts)

def extract(archive_path, destination):
    archive_path = Path(archive_path)
    root = Path(destination)
    if root.is_symlink():
        raise ValueError('"'"'Extraction destination is symlink'"'"')
    for ancestor in root.parents:
        if ancestor.is_symlink():
            raise ValueError('"'"'Extraction ancestor is symlink'"'"')
    root.mkdir(parents=True, exist_ok=True)
    root = root.resolve(strict=True)
    if not root.is_dir():
        raise ValueError('"'"'Extraction destination is not directory'"'"')
    mode = '"'"'zip'"'"' if zipfile.is_zipfile(archive_path) else '"'"'tar'"'"'
    with (zipfile.ZipFile(archive_path) if mode == '"'"'zip'"'"' else tarfile.open(archive_path, '"'"'r:*'"'"')) as archive:
        members = archive.infolist() if mode == '"'"'zip'"'"' else archive.getmembers()
        if len(members) > MAX_MEMBERS:
            raise ValueError('"'"'Too many archive members'"'"')
        seen = set()
        total = 0
        validated = []
        for member in members:
            name = member.filename if mode == '"'"'zip'"'"' else member.name
            if name in (".", "./") and ((member.is_dir() if mode == '"'"'zip'"'"' else member.isdir())):
                continue
            key = checked_name(name)
            if key in seen:
                raise ValueError(f'"'"'Duplicate archive entry: {name!r}'"'"')
            seen.add(key)
            if mode == '"'"'zip'"'"':
                kind = (member.external_attr >> 16) & 0o170000
                is_dir = member.is_dir()
                if kind not in (0, stat.S_IFREG, stat.S_IFDIR) or (is_dir and kind == stat.S_IFREG):
                    raise ValueError(f'"'"'Unsafe ZIP file type: {name!r}'"'"')
                size = member.file_size
            else:
                is_dir = member.isdir()
                if not (is_dir or member.isfile()):
                    raise ValueError(f'"'"'Unsafe TAR file type/link: {name!r}'"'"')
                size = member.size
            total += size
            if total > MAX_TOTAL_SIZE:
                raise ValueError('"'"'Archive exceeds extraction size limit'"'"')
            validated.append((member, key, is_dir))
        # Validate collisions between ancestor files and descendants before writing.
        file_keys = {key for _, key, is_dir in validated if not is_dir}
        for _, key, _ in validated:
            if any(key[:i] in file_keys for i in range(1, len(key))):
                raise ValueError(f'"'"'File used as directory: {key!r}'"'"')
        # Refuse existing symlink parents and destinations even inside staging roots.
        for _, key, _ in validated:
            target = root
            for part in key:
                target = target / part
                if target.is_symlink():
                    raise ValueError(f'"'"'Existing symlink within extraction: {target}'"'"')
                if target.exists() and not (target.is_dir() or target.is_file()):
                    raise ValueError(f'"'"'Existing special file: {target}'"'"')
        for member, key, is_dir in validated:
            target = root.joinpath(*key)
            if is_dir:
                if target.exists() and not target.is_dir():
                    raise ValueError(f'"'"'Directory collides with existing file: {target}'"'"')
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with (archive.open(member, '"'"'r'"'"') if mode == '"'"'zip'"'"' else archive.extractfile(member)) as source:
                if source is None:
                    raise ValueError('"'"'Missing member file content'"'"')
                with target.open('"'"'xb'"'"') as output:
                    while True:
                        chunk = source.read(1024*1024)
                        if not chunk:
                            break
                        output.write(chunk)
            # Preserve executable mode for known regular files, never special bits.
            permissions = ((member.external_attr >> 16) if mode == '"'"'zip'"'"' else member.mode) & 0o777
            os.chmod(target, permissions & 0o777)

if __name__ == '"'"'__main__'"'"':
    if len(sys.argv) != 3:
        raise SystemExit('"'"'Usage: bua_safe_extract.py ARCHIVE DESTINATION'"'"')
    try:
        extract(sys.argv[1], sys.argv[2])
    except Exception as exc:
        print(f'"'"'[BUA] Unsafe or invalid archive rejected: {exc}'"'"', file=sys.stderr)
        raise SystemExit(1)
' "$UPDATER_TMP" "$UPDATER_STAGE"; then
    echo "BUA updater extraction failed; existing updater preserved."
    rm -rf "$UPDATER_STAGE"
    exit 1
fi

for required in \
    bua_installerx86.py \
    catalog/build_global_update_manifest.py \
    catalog/global/app-update-recipes.json \
    integrations/apply_switch_nextendo.py
do
    if [ ! -f "$UPDATER_STAGE/updater/$required" ]; then
        echo "BUA updater package incomplete: $required"
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi
done

printf '%s\\n' "$UPDATER_SUPPORT_SHA256" > \
    "$UPDATER_STAGE/updater/.bua-support-sha256"

# Authenticate matching verification metadata before modifying the updater.
UPDATER_VERIFICATION_TMP="$UPDATER_STAGE/verification.tar.gz"

if ! curl -fLs \
    -o "$UPDATER_VERIFICATION_TMP" \
    "$UPDATER_VERIFICATION_URL"; then
    echo "BUA verification bundle download failed."
    rm -rf "$UPDATER_STAGE"
    exit 1
fi

DOWNLOADED_VERIFICATION_SHA256="$(
    sha256sum "$UPDATER_VERIFICATION_TMP" | awk '{print $1}'
)"

if [ "$DOWNLOADED_VERIFICATION_SHA256" != "$UPDATER_VERIFICATION_SHA256" ]; then
    echo "BUA verification bundle checksum mismatch."
    rm -rf "$UPDATER_STAGE"
    exit 1
fi

if ! python3 -c '#!/usr/bin/env python3
"""BUA archive extraction guard. Deliberately rejects links, special files and duplicate paths."""
import os
import stat
import sys
import tarfile
import zipfile
from pathlib import Path, PurePosixPath

MAX_MEMBERS = 100000
MAX_TOTAL_SIZE = 20 * 1024**3

def checked_name(name):
    if not isinstance(name, str) or not name or '"'"'\\'"'"' in name or '"'"'\x00'"'"' in name:
        raise ValueError(f'"'"'Unsafe archive name: {name!r}'"'"')
    if name.startswith('"'"'/'"'"') or name.startswith('"'"'//'"'"'):
        raise ValueError(f'"'"'Absolute archive path: {name!r}'"'"')
    parts = name.rstrip('"'"'/'"'"').split('"'"'/'"'"')
    if parts and parts[0] == '"'"'.'"'"':
        parts = parts[1:]
    if not parts or any(x in ('"'"''"'"', '"'"'.'"'"', '"'"'..'"'"') for x in parts):
        raise ValueError(f'"'"'Traversal or noncanonical path: {name!r}'"'"')
    if '"'"':'"'"' in parts[0]:
        raise ValueError(f'"'"'Drive-like archive path: {name!r}'"'"')
    return tuple(parts)

def extract(archive_path, destination):
    archive_path = Path(archive_path)
    root = Path(destination)
    if root.is_symlink():
        raise ValueError('"'"'Extraction destination is symlink'"'"')
    for ancestor in root.parents:
        if ancestor.is_symlink():
            raise ValueError('"'"'Extraction ancestor is symlink'"'"')
    root.mkdir(parents=True, exist_ok=True)
    root = root.resolve(strict=True)
    if not root.is_dir():
        raise ValueError('"'"'Extraction destination is not directory'"'"')
    mode = '"'"'zip'"'"' if zipfile.is_zipfile(archive_path) else '"'"'tar'"'"'
    with (zipfile.ZipFile(archive_path) if mode == '"'"'zip'"'"' else tarfile.open(archive_path, '"'"'r:*'"'"')) as archive:
        members = archive.infolist() if mode == '"'"'zip'"'"' else archive.getmembers()
        if len(members) > MAX_MEMBERS:
            raise ValueError('"'"'Too many archive members'"'"')
        seen = set()
        total = 0
        validated = []
        for member in members:
            name = member.filename if mode == '"'"'zip'"'"' else member.name
            if name in (".", "./") and ((member.is_dir() if mode == '"'"'zip'"'"' else member.isdir())):
                continue
            key = checked_name(name)
            if key in seen:
                raise ValueError(f'"'"'Duplicate archive entry: {name!r}'"'"')
            seen.add(key)
            if mode == '"'"'zip'"'"':
                kind = (member.external_attr >> 16) & 0o170000
                is_dir = member.is_dir()
                if kind not in (0, stat.S_IFREG, stat.S_IFDIR) or (is_dir and kind == stat.S_IFREG):
                    raise ValueError(f'"'"'Unsafe ZIP file type: {name!r}'"'"')
                size = member.file_size
            else:
                is_dir = member.isdir()
                if not (is_dir or member.isfile()):
                    raise ValueError(f'"'"'Unsafe TAR file type/link: {name!r}'"'"')
                size = member.size
            total += size
            if total > MAX_TOTAL_SIZE:
                raise ValueError('"'"'Archive exceeds extraction size limit'"'"')
            validated.append((member, key, is_dir))
        # Validate collisions between ancestor files and descendants before writing.
        file_keys = {key for _, key, is_dir in validated if not is_dir}
        for _, key, _ in validated:
            if any(key[:i] in file_keys for i in range(1, len(key))):
                raise ValueError(f'"'"'File used as directory: {key!r}'"'"')
        # Refuse existing symlink parents and destinations even inside staging roots.
        for _, key, _ in validated:
            target = root
            for part in key:
                target = target / part
                if target.is_symlink():
                    raise ValueError(f'"'"'Existing symlink within extraction: {target}'"'"')
                if target.exists() and not (target.is_dir() or target.is_file()):
                    raise ValueError(f'"'"'Existing special file: {target}'"'"')
        for member, key, is_dir in validated:
            target = root.joinpath(*key)
            if is_dir:
                if target.exists() and not target.is_dir():
                    raise ValueError(f'"'"'Directory collides with existing file: {target}'"'"')
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with (archive.open(member, '"'"'r'"'"') if mode == '"'"'zip'"'"' else archive.extractfile(member)) as source:
                if source is None:
                    raise ValueError('"'"'Missing member file content'"'"')
                with target.open('"'"'xb'"'"') as output:
                    while True:
                        chunk = source.read(1024*1024)
                        if not chunk:
                            break
                        output.write(chunk)
            # Preserve executable mode for known regular files, never special bits.
            permissions = ((member.external_attr >> 16) if mode == '"'"'zip'"'"' else member.mode) & 0o777
            os.chmod(target, permissions & 0o777)

if __name__ == '"'"'__main__'"'"':
    if len(sys.argv) != 3:
        raise SystemExit('"'"'Usage: bua_safe_extract.py ARCHIVE DESTINATION'"'"')
    try:
        extract(sys.argv[1], sys.argv[2])
    except Exception as exc:
        print(f'"'"'[BUA] Unsafe or invalid archive rejected: {exc}'"'"', file=sys.stderr)
        raise SystemExit(1)
' "$UPDATER_VERIFICATION_TMP" "$UPDATER_STAGE"; then
    echo "BUA verification bundle extraction failed."
    rm -rf "$UPDATER_STAGE"
    exit 1
fi

for required in \
    bua-updater-compatibility.json \
    bua-updater-package-integrity.json \
    bua_updater_integrity.py
do
    if [ ! -f "$UPDATER_STAGE/verification/$required" ]; then
        echo "BUA verification bundle incomplete: $required"
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi
done

printf '%s\n' "$UPDATER_VERIFICATION_SHA256" > \
    "$UPDATER_STAGE/verification/.bua-verification-sha256"

echo "BUA updater and verification bundles staged successfully."

# Publish the SHA256-authenticated verification archive before activation.
# Keep it outside updater/ and verification/ so it survives recovery.
UPDATER_TRUSTED_CACHE="$UPDATER_BASE/.bua-verification-trusted.tar.gz"
UPDATER_CACHE_TEMP=""

if [ -L "$UPDATER_TRUSTED_CACHE" ]; then
    echo "BUA trusted verification cache is an unexpected symlink."
    rm -rf "$UPDATER_STAGE"
    exit 1
fi

if [ -e "$UPDATER_TRUSTED_CACHE" ]; then
    if [ ! -f "$UPDATER_TRUSTED_CACHE" ]; then
        echo "BUA trusted verification cache has an unexpected type."
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi

    EXISTING_CACHE_SHA256="$(
        sha256sum "$UPDATER_TRUSTED_CACHE" | awk '{print $1}'
    )"

    if [ "$EXISTING_CACHE_SHA256" != "$UPDATER_VERIFICATION_SHA256" ]; then
        echo "BUA trusted verification cache is corrupted; refusing replacement."
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi

    echo "Existing authenticated BUA verification cache retained."
else
    UPDATER_CACHE_TEMP="$(
        mktemp "$UPDATER_BASE/.bua-verification-cache.XXXXXX"
    )" || {
        echo "Unable to allocate trusted verification cache staging file."
        rm -rf "$UPDATER_STAGE"
        exit 1
    }

    if ! cp "$UPDATER_VERIFICATION_TMP" "$UPDATER_CACHE_TEMP"; then
        echo "Unable to stage trusted verification cache."
        rm -f "$UPDATER_CACHE_TEMP"
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi

    STAGED_CACHE_SHA256="$(
        sha256sum "$UPDATER_CACHE_TEMP" | awk '{print $1}'
    )"

    if [ "$STAGED_CACHE_SHA256" != "$UPDATER_VERIFICATION_SHA256" ]; then
        echo "Staged trusted cache checksum mismatch."
        rm -f "$UPDATER_CACHE_TEMP"
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi

    if [ -e "$UPDATER_TRUSTED_CACHE" ] || [ -L "$UPDATER_TRUSTED_CACHE" ]; then
        echo "Trusted cache destination appeared unexpectedly."
        rm -f "$UPDATER_CACHE_TEMP"
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi

    if ! mv "$UPDATER_CACHE_TEMP" "$UPDATER_TRUSTED_CACHE"; then
        echo "Unable to publish trusted verification cache."
        rm -f "$UPDATER_CACHE_TEMP"
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi

    echo "Authenticated BUA verification cache published."
fi


# Preserve both active directories before activating the new pair.
UPDATER_VERIFICATION_PREVIOUS="$UPDATER_BASE/.bua-verification-previous"
UPDATER_VERIFICATION_BACKUPS="$UPDATER_BASE/.bua-verification-backups"

for recovery in "$UPDATER_PREVIOUS" "$UPDATER_VERIFICATION_PREVIOUS"; do
    if [ -e "$recovery" ] || [ -L "$recovery" ]; then
        echo "Unresolved BUA recovery directory: $recovery"
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi
done

for active in "$UPDATER_ROOT" "$UPDATER_VERIFICATION_ROOT"; do
    if [ -e "$active" ] || [ -L "$active" ]; then
        if [ -L "$active" ] || [ ! -d "$active" ]; then
            echo "Unexpected BUA installation type: $active"
            rm -rf "$UPDATER_STAGE"
            exit 1
        fi
    fi
done

HAD_UPDATER=0
HAD_VERIFICATION=0

if [ -d "$UPDATER_ROOT" ]; then
    if ! mv "$UPDATER_ROOT" "$UPDATER_PREVIOUS"; then
        echo "Failed to preserve previous updater."
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi
    HAD_UPDATER=1
fi

if [ -d "$UPDATER_VERIFICATION_ROOT" ]; then
    if ! mv "$UPDATER_VERIFICATION_ROOT" "$UPDATER_VERIFICATION_PREVIOUS"; then
        echo "Failed to preserve previous verification metadata."
        if [ "$HAD_UPDATER" -eq 1 ]; then
            mv "$UPDATER_PREVIOUS" "$UPDATER_ROOT" || \
                echo "CRITICAL: Updater recovery requires manual repair."
        fi
        rm -rf "$UPDATER_STAGE"
        exit 1
    fi
    HAD_VERIFICATION=1
fi

NEW_UPDATER_ACTIVE=0
NEW_VERIFICATION_ACTIVE=0

if mv "$UPDATER_STAGE/updater" "$UPDATER_ROOT"; then
    NEW_UPDATER_ACTIVE=1
fi

if [ "$NEW_UPDATER_ACTIVE" -eq 1 ]; then
    if mv "$UPDATER_STAGE/verification" "$UPDATER_VERIFICATION_ROOT"; then
        NEW_VERIFICATION_ACTIVE=1
    fi
fi

if [ "$NEW_UPDATER_ACTIVE" -ne 1 ] || [ "$NEW_VERIFICATION_ACTIVE" -ne 1 ]; then
    echo "BUA coordinated activation failed; restoring previous installation."

    if [ "$NEW_VERIFICATION_ACTIVE" -eq 1 ]; then
        mv "$UPDATER_VERIFICATION_ROOT" \
           "$UPDATER_STAGE/verification-failed" || \
            echo "CRITICAL: Cannot isolate failed verification installation."
    fi

    if [ "$NEW_UPDATER_ACTIVE" -eq 1 ]; then
        mv "$UPDATER_ROOT" "$UPDATER_STAGE/updater-failed" || \
            echo "CRITICAL: Cannot isolate failed updater installation."
    fi

    ROLLBACK_FAILED=0

    if [ "$HAD_UPDATER" -eq 1 ]; then
        if ! mv "$UPDATER_PREVIOUS" "$UPDATER_ROOT"; then
            echo "CRITICAL: Previous updater restoration failed."
            ROLLBACK_FAILED=1
        fi
    fi

    if [ "$HAD_VERIFICATION" -eq 1 ]; then
        if ! mv "$UPDATER_VERIFICATION_PREVIOUS" \
            "$UPDATER_VERIFICATION_ROOT"; then
            echo "CRITICAL: Previous verification restoration failed."
            ROLLBACK_FAILED=1
        fi
    fi

    if [ "$ROLLBACK_FAILED" -eq 0 ]; then
        rm -rf "$UPDATER_STAGE"
    else
        echo "CRITICAL: Staging files retained for manual recovery."
        echo "RECOVERY STAGE: $UPDATER_STAGE"
    fi

    exit 1
fi

# Both new directories are active. Retain each previous version.
# Backup retention failures do not invalidate an already activated pair.
retain_previous() {
    local previous="$1"
    local backup_root="$2"
    local backup_slot

    [ -d "$previous" ] || return 0

    if ! mkdir -p "$backup_root"; then
        echo "WARNING: Cannot create backup directory: $backup_root"
        return 0
    fi

    backup_slot="$(mktemp -d "$backup_root/previous.XXXXXX")" || {
        echo "WARNING: Cannot allocate backup slot: $backup_root"
        return 0
    }

    rmdir "$backup_slot"

    if ! mv "$previous" "$backup_slot"; then
        echo "WARNING: Previous installation retained at $previous"
    fi
}

# Verify the activated updater against authenticated metadata before
# retaining previous installations or declaring installation successful.
bua_verify_installed_pair() {
    python3 - "$1" "$2" "$UPDATER_TRUSTED_CACHE" "$UPDATER_VERIFICATION_SHA256" <<'BUA_VERIFY_PAIR'
import hashlib
import importlib.util
import json
import sys
import tarfile
from pathlib import Path

updater, verification, bundle = map(Path, sys.argv[1:4])
expected_sha = sys.argv[4]
expected_package = "c8f11750bcf6534df8a44c22f6487ee8ab207b6798ac5f3efa2a9aae44eb05e5"

try:
    if bundle.is_symlink() or not bundle.is_file():
        raise RuntimeError("Trusted bundle unavailable")

    if hashlib.sha256(bundle.read_bytes()).hexdigest() != expected_sha:
        raise RuntimeError("Trusted bundle checksum mismatch")

    expected_files = {
        "bua-updater-compatibility.json",
        "bua-updater-package-integrity.json",
        "bua_updater_integrity.py",
    }

    with tarfile.open(bundle, "r:gz") as archive:
        members = archive.getmembers()
        names = set()

        for member in members:
            parts = Path(member.name).parts
            if (
                not member.isfile()
                or len(parts) != 2
                or parts[0] != "verification"
                or parts[1] not in expected_files
                or parts[1] in names
            ):
                raise RuntimeError("Unexpected verification archive entry")

            names.add(parts[1])
            installed = verification / parts[1]

            if installed.is_symlink() or not installed.is_file():
                raise RuntimeError("Missing trusted verification file")

            with archive.extractfile(member) as stream:
                trusted_hash = hashlib.sha256(stream.read()).digest()

            if hashlib.sha256(installed.read_bytes()).digest() != trusted_hash:
                raise RuntimeError("Verification metadata modified")

        if names != expected_files:
            raise RuntimeError("Incomplete verification archive")

    manifest = verification / "bua-updater-package-integrity.json"
    contract = verification / "bua-updater-compatibility.json"
    verifier = verification / "bua_updater_integrity.py"

    if json.loads(manifest.read_text()).get("package_sha256") != expected_package:
        raise RuntimeError("Unexpected previous updater identity")

    if json.loads(contract.read_text()).get("backend_api_version") != 1:
        raise RuntimeError("Incompatible previous updater")

    spec = importlib.util.spec_from_file_location("bua_rollback_integrity", verifier)
    if spec is None or spec.loader is None:
        raise RuntimeError("Verifier loading failed")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    valid, reason = module.verify_updater_installation(
        updater, manifest, contract, frontend_api_version=1
    )
    print(reason)

    if not valid:
        sys.exit(1)

except Exception as exc:
    print("BUA previous installation authentication failed:", exc)
    sys.exit(1)
BUA_VERIFY_PAIR
}

BUA_POST_ACTIVATION_VERIFIED=0

if bua_verify_installed_pair "$UPDATER_ROOT" "$UPDATER_VERIFICATION_ROOT"; then
    BUA_POST_ACTIVATION_VERIFIED=1
fi

if [ "$BUA_POST_ACTIVATION_VERIFIED" -ne 1 ]; then
    echo "BUA installation verification failed; initiating rollback."

    BUA_FAILED_INSTALL="$UPDATER_BASE/.bua-failed-activation"
    BUA_FAILED_UPDATER="$BUA_FAILED_INSTALL/updater"
    BUA_FAILED_VERIFICATION="$BUA_FAILED_INSTALL/verification"

    if [ -e "$BUA_FAILED_INSTALL" ] || [ -L "$BUA_FAILED_INSTALL" ]; then
        echo "CRITICAL: Existing failed-installation recovery directory."
        exit 1
    fi

    if ! mkdir "$BUA_FAILED_INSTALL"; then
        echo "CRITICAL: Cannot create failed-installation recovery directory."
        exit 1
    fi

    # Never overwrite a recovery destination.
    if ! mv "$UPDATER_ROOT" "$BUA_FAILED_UPDATER"; then
        echo "CRITICAL: Cannot isolate failed updater."
        exit 1
    fi

    if ! mv "$UPDATER_VERIFICATION_ROOT" "$BUA_FAILED_VERIFICATION"; then
        echo "CRITICAL: Cannot isolate failed verification metadata."
        exit 1
    fi

    # Authenticate the previous pair before restoring either directory.
    # Never load verification code until its bytes match the trusted archive.
    if [ "$HAD_UPDATER" -eq 1 ] && [ "$HAD_VERIFICATION" -eq 1 ]; then
        if ! bua_verify_installed_pair \
            "$UPDATER_PREVIOUS" \
            "$UPDATER_VERIFICATION_PREVIOUS"
        then
            echo "CRITICAL: Previous updater is not authenticated."
            echo "Recovery files retained. Manual recovery required."
            exit 1
        fi
    else
        echo "No complete previous updater/verification pair available."
        echo "Cannot authorize verified rollback."
        exit 1
    fi

    BUA_RESTORE_FAILED=0

    if [ "$HAD_UPDATER" -eq 1 ]; then
        mv "$UPDATER_PREVIOUS" "$UPDATER_ROOT" || BUA_RESTORE_FAILED=1
    fi

    if [ "$HAD_VERIFICATION" -eq 1 ]; then
        mv "$UPDATER_VERIFICATION_PREVIOUS"            "$UPDATER_VERIFICATION_ROOT" || BUA_RESTORE_FAILED=1
    fi

    if [ "$BUA_RESTORE_FAILED" -ne 0 ]; then
        echo "CRITICAL: Previous installation restoration incomplete."
        echo "Recovery files preserved at $BUA_FAILED_INSTALL"
        exit 1
    fi

    # Require fresh verification after both previous directories have been restored.
    if ! bua_verify_installed_pair \
        "$UPDATER_ROOT" \
        "$UPDATER_VERIFICATION_ROOT"; then
        echo "CRITICAL: Restored BUA updater failed integrity verification."
        echo "Recovery files preserved at $BUA_FAILED_INSTALL"
        exit 1
    fi

    echo "Previous installation directories restored and authenticated."
    echo "Failed installation preserved at $BUA_FAILED_INSTALL"
    exit 1
fi

retain_previous "$UPDATER_PREVIOUS" "$UPDATER_BACKUPS"
retain_previous "$UPDATER_VERIFICATION_PREVIOUS" \
    "$UPDATER_VERIFICATION_BACKUPS"

rm -rf "$UPDATER_STAGE"
rm -f "$UPDATER_TMP"

echo "BUA global updater support installed."

# Release the shared updater installation lock.
flock -u 9
exec 9>&-

# Apply optional Switch/Citron integration if Switch is installed.
NEXTENDO_PATCHER="$UPDATER_ROOT/integrations/apply_switch_nextendo.py"

if [ -f "$NEXTENDO_PATCHER" ]; then
    echo "Checking Switch/Citron NexTendo integration..."
    python3 "$NEXTENDO_PATCHER" || \
        echo "Warning: NexTendo integration check failed."
fi


# Download xmlstarlet
echo "Downloading xmlstarlet..."
mkdir -p "$(dirname "$XMLSTARLET_DEST")"
wget --show-progress -O "$XMLSTARLET_DEST" "$XMLSTARLET_URL"

if [ ! -s "$XMLSTARLET_DEST" ]; then
    echo "Failed to download xmlstarlet. Exiting."
    exit 1
fi

chmod +x "$XMLSTARLET_DEST"

echo "Creating symlink for xmlstarlet in /usr/bin..."
ln -sf "$XMLSTARLET_DEST" /usr/bin/xmlstarlet

# Download the bua command-line tool. symlink_manager links it into /usr/bin
# at boot; link it now so it works straight away.
echo "Downloading the bua command-line tool..."
mkdir -p "$(dirname "${BUA_CLI_DEST}")"
wget --show-progress -O "${BUA_CLI_DEST}" "${BUA_CLI_URL}"

if [ ! -s "${BUA_CLI_DEST}" ]; then
    echo "Failed to download the bua command-line tool. Exiting."
    exit 1
fi

chmod +x "${BUA_CLI_DEST}"
ln -sf "${BUA_CLI_DEST}" /usr/bin/bua

echo "Downloading icon..."
wget --show-progress -O "/userdata/system/add-ons/${APPNAME_LC}/extra/icon.png" "$ICON_URL"

echo "Creating persistent desktop entry for ${APPNAME}..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Batocera Unofficial Add Ons
Exec=/userdata/roms/ports/bua.sh
Icon=/userdata/system/add-ons/${APPNAME_LC}/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"
cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

echo "Creating restore script for ${APPNAME} desktop entry..."
cat <<EOF > "$RESTORE_SCRIPT"
#!/bin/bash
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring ${APPNAME} desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
fi
EOF

chmod +x "$RESTORE_SCRIPT"

# Add restore script to startup if not already present
if ! grep -q "$RESTORE_SCRIPT" "$CUSTOM_STARTUP"; then
    echo "Adding ${APPNAME} restore script to startup..."
    echo "bash \"$RESTORE_SCRIPT\" &" >> "$CUSTOM_STARTUP"
fi

chmod +x "$CUSTOM_STARTUP"

echo "Refreshing Ports menu (non-fatal)..."
curl -fs http://127.0.0.1:1234/reloadgames || true

# Ensure gamelist.xml exists
if [ ! -f "$GAMELIST_XML" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$GAMELIST_XML"
fi

echo "Downloading Batocera Unofficial Add-ons logo..."
curl -fLs -o "$BATOCERA_ADDONS_LOGO_DEST" "$BATOCERA_ADDONS_LOGO_URL"
if [ ! -s "$BATOCERA_ADDONS_LOGO_DEST" ]; then
    echo "Failed to download logo. Exiting."
    exit 1
fi

echo "Downloading Batocera Unofficial Add-ons wheel..."
curl -fLs -o "$BATOCERA_ADDONS_WHEEL_DEST" "$BATOCERA_ADDONS_WHEEL_URL"
if [ ! -s "$BATOCERA_ADDONS_WHEEL_DEST" ]; then
    echo "Failed to download wheel image. Exiting."
    exit 1
fi

# Make gamelist.xml idempotent for ./bua.sh
echo "Updating gamelist.xml entry for BUA..."
# Remove any existing entries for ./bua.sh
xmlstarlet ed \
  -P -L \
  -d "/gameList/game[path='./bua.sh']" \
  "$GAMELIST_XML"

# Append fresh entry
xmlstarlet ed \
  -P \
  -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./bua.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Batocera Unofficial Add-Ons Installer" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/BatoceraUnofficialAddons.png" \
  -s "/gameList/game[last()]" -t elem -n "marquee" -v "./images/BatoceraUnofficialAddons_Wheel.png" \
  "$GAMELIST_XML" > "${GAMELIST_XML}.tmp"

mv "${GAMELIST_XML}.tmp" "$GAMELIST_XML"

curl -fs http://127.0.0.1:1234/reloadgames || true

# Install BUA Python hook (enables add-on configgen generators)
echo "Installing BUA Python hook..."
USERCUSTOMIZE_DIR="/userdata/system/.local/lib/python3.12/site-packages"
mkdir -p "$USERCUSTOMIZE_DIR"
curl -fLs -o "$USERCUSTOMIZE_DIR/usercustomize.py" \
    "https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/usercustomize.py"

echo
echo "Installation complete! You can now launch Batocera Unofficial Add-Ons from the Ports menu."
