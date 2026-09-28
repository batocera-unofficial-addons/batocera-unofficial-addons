#!/usr/bin/env bash

set -e

BASE="https://raw.githubusercontent.com/klova5/batocera-unofficial-addons/feature/global-parent-source-updater/app"

INSTALL_ROOT="/userdata/system/add-ons/bua-global-updater"
PORTS_LAUNCHER="/userdata/roms/ports/bua-test.sh"

ARCHIVE_NAME="bua-global-updater-test-x86_64.tar.gz"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"

ARCHIVE="/tmp/${ARCHIVE_NAME}"
CHECKSUM="/tmp/${CHECKSUM_NAME}"

echo
echo "============================================"
echo " BUA Global Updater - Test Build"
echo "============================================"
echo

ARCH="$(uname -m)"

if [ "$ARCH" != "x86_64" ]; then
    echo "[BUA Test] ERROR: x86_64 only."
    echo "[BUA Test] Detected: $ARCH"
    exit 1
fi

echo "[BUA Test] Downloading checksum..."

curl -fsSL \
    "$BASE/$CHECKSUM_NAME" \
    -o "$CHECKSUM"

echo "[BUA Test] Downloading package..."

curl -fL \
    "$BASE/$ARCHIVE_NAME" \
    -o "$ARCHIVE"

EXPECTED="$(awk 'NR==1 {print $1}' "$CHECKSUM")"
ACTUAL="$(sha256sum "$ARCHIVE" | awk '{print $1}')"

if [ -z "$EXPECTED" ] || [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "[BUA Test] ERROR: checksum verification failed."
    exit 1
fi

echo "[BUA Test] Checksum verified."

NEW="${INSTALL_ROOT}.new"
OLD="${INSTALL_ROOT}.old"

rm -rf "$NEW" "$OLD"
mkdir -p "$NEW"

tar -xzf "$ARCHIVE" -C "$NEW"

if [ ! -f "$NEW/bua_installerx86.py" ] || \
   [ ! -d "$NEW/updater" ]; then
    echo "[BUA Test] ERROR: package incomplete."
    rm -rf "$NEW"
    exit 1
fi

printf '%s\n' "$ACTUAL" > "$NEW/.bundle.sha256"

if [ -d "$INSTALL_ROOT" ]; then
    mv "$INSTALL_ROOT" "$OLD"
fi

if ! mv "$NEW" "$INSTALL_ROOT"; then
    echo "[BUA Test] ERROR: install failed."

    rm -rf "$NEW"

    if [ -d "$OLD" ]; then
        mv "$OLD" "$INSTALL_ROOT"
    fi

    exit 1
fi

rm -rf "$OLD"

cat > "$PORTS_LAUNCHER" <<'LAUNCHER'
#!/bin/bash

export DISPLAY=:0
export XAUTHORITY=/.Xauthority

exec python3 \
  /userdata/system/add-ons/bua-global-updater/bua_installerx86.py
LAUNCHER

chmod +x "$PORTS_LAUNCHER"

curl -fs \
  http://127.0.0.1:1234/reloadgames \
  >/dev/null 2>&1 || true

rm -f "$ARCHIVE" "$CHECKSUM"

echo
echo "============================================"
echo " BUA Test installed successfully."
echo "============================================"
echo
echo "Official BUA was not modified."
echo "Launch 'bua-test' from Ports."
echo
