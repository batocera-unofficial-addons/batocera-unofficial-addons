#!/usr/bin/env bash

set -e

BASE="https://raw.githubusercontent.com/klova5/batocera-unofficial-addons/feature/global-parent-source-updater/app"

INSTALL_ROOT="/userdata/system/add-ons/bua"
PORTS_LAUNCHER="/userdata/roms/ports/bua.sh"

ARCHIVE="/tmp/bua-updater-support-x86_64.tar.gz"
CHECKSUM="/tmp/bua-updater-support-x86_64.tar.gz.sha256"

echo "[BUA] Downloading update..."

curl -fsSL \
  "$BASE/bua-updater-support-x86_64.tar.gz.sha256" \
  -o "$CHECKSUM"

curl -fL \
  "$BASE/bua-updater-support-x86_64.tar.gz" \
  -o "$ARCHIVE"

echo "[BUA] Verifying package..."

EXPECTED="$(awk 'NR==1 {print $1}' "$CHECKSUM")"
ACTUAL="$(sha256sum "$ARCHIVE" | awk '{print $1}')"

if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "[BUA] ERROR: checksum verification failed."
    exit 1
fi

NEW="${INSTALL_ROOT}.new"
OLD="${INSTALL_ROOT}.old"

rm -rf "$NEW" "$OLD"
mkdir -p "$NEW"

tar -xzf "$ARCHIVE" -C "$NEW"

printf '%s\n' "$ACTUAL" > "$NEW/.bundle.sha256"

if [ -d "$INSTALL_ROOT" ]; then
    mv "$INSTALL_ROOT" "$OLD"
fi

if ! mv "$NEW" "$INSTALL_ROOT"; then
    echo "[BUA] ERROR: installation failed."
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

exec python3 /userdata/system/add-ons/bua/bua_installerx86.py
LAUNCHER

chmod +x "$PORTS_LAUNCHER"

rm -f "$ARCHIVE" "$CHECKSUM"

echo
echo "[BUA] Installation complete."
echo "[BUA] Refresh EmulationStation and launch BUA from Ports."
