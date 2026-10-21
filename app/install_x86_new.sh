#!/bin/bash

# URLs
SCRIPT_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/app/symlinks.sh"
BATOCERA_ADDONS_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/BUA.sh"
UPDATER_SUPPORT_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/bua-updater-support-x86_64.tar.gz"
UPDATER_SUPPORT_SHA256="64affa257acc580ddcb39d14188e6c6bdd24d2c039b6a87d69e63af4646f7b90"
UPDATER_ROOT="/userdata/system/add-ons/bua/updater"

# Authenticated updater verification metadata.
UPDATER_VERIFICATION_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/bua-updater-verification-x86_64.tar.gz"
UPDATER_VERIFICATION_SHA256="6c2543a5af8117680f48313591aca486650d492c67ec8eb635b33c9f11e00d76"
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

if ! tar -xzf "$UPDATER_TMP" -C "$UPDATER_STAGE"; then
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

if ! tar -xzf "$UPDATER_VERIFICATION_TMP" -C "$UPDATER_STAGE"; then
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
expected_package = "64affa257acc580ddcb39d14188e6c6bdd24d2c039b6a87d69e63af4646f7b90"

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
