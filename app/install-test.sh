#!/usr/bin/env bash

set -e

BASE="https://raw.githubusercontent.com/klova5/batocera-unofficial-addons/feature/global-parent-source-updater/app"

INSTALL_ROOT="/userdata/system/add-ons/bua-global-updater"
PORTS_DIR="/userdata/roms/ports"
PORTS_LAUNCHER="${PORTS_DIR}/bua-test.sh"

ARCHIVE_NAME="bua-global-updater-test-x86_64.tar.gz"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"

ARCHIVE="/tmp/${ARCHIVE_NAME}"
CHECKSUM="/tmp/${CHECKSUM_NAME}"

echo
echo "============================================"
echo " BUA Global Updater - Compatibility Preflight"
echo "============================================"
echo

FAIL=0

check_cmd() {
    name="$1"

    if command -v "$name" >/dev/null 2>&1; then
        printf "%-28s %s\n" "$name:" "OK"
    else
        printf "%-28s %s\n" "$name:" "MISSING"
        FAIL=1
    fi
}

ARCH="$(uname -m 2>/dev/null || echo unknown)"

if [ "$ARCH" = "x86_64" ]; then
    printf "%-28s %s\n" "Architecture:" "$ARCH OK"
else
    printf "%-28s %s\n" "Architecture:" "$ARCH UNSUPPORTED"
    FAIL=1
fi

if [ -d /userdata ] && [ -w /userdata ]; then
    printf "%-28s %s\n" "/userdata writable:" "OK"
else
    printf "%-28s %s\n" "/userdata writable:" "FAILED"
    FAIL=1
fi

if [ -d "$PORTS_DIR" ] && [ -w "$PORTS_DIR" ]; then
    printf "%-28s %s\n" "Ports directory:" "OK"
else
    printf "%-28s %s\n" "Ports directory:" "FAILED"
    FAIL=1
fi

check_cmd bash
check_cmd curl
check_cmd tar
check_cmd sha256sum
check_cmd python3
check_cmd awk
check_cmd uname

BATOCERA_VERSION="unknown"

if command -v batocera-es-swissknife >/dev/null 2>&1; then
    BATOCERA_VERSION="$(
        batocera-es-swissknife --version 2>/dev/null | head -1 || true
    )"
elif [ -f /usr/share/batocera/batocera.version ]; then
    BATOCERA_VERSION="$(
        cat /usr/share/batocera/batocera.version 2>/dev/null || true
    )"
elif [ -f /etc/os-release ]; then
    BATOCERA_VERSION="$(
        grep '^VERSION=' /etc/os-release 2>/dev/null \
        | head -1 \
        | cut -d= -f2- \
        | tr -d '"'
    )"
fi

[ -n "$BATOCERA_VERSION" ] || BATOCERA_VERSION="unknown"

BATOCERA_MAJOR="$(
    printf '%s\n' "$BATOCERA_VERSION" \
    | grep -oE '[0-9]+' \
    | head -1
)"

# Test-only override so version-gating logic can be simulated
# without downgrading the actual Batocera system.
if [ -n "${BUA_TEST_BATOCERA_MAJOR:-}" ]; then
    BATOCERA_MAJOR="$BUA_TEST_BATOCERA_MAJOR"
    BATOCERA_VERSION="SIMULATED-$BATOCERA_MAJOR"
fi

printf "%-28s %s\n" "Batocera version:" "$BATOCERA_VERSION"

case "$BATOCERA_MAJOR" in
    44)
        printf "%-28s %s\n" "Version policy:" "SUPPORTED"
        ;;
    43|42)
        printf "%-28s %s\n" "Version policy:" "ALLOWED - UNVERIFIED"
        ;;
    ''|*[!0-9]*)
        printf "%-28s %s\n" "Version policy:" "UNKNOWN"
        FAIL=1
        ;;
    *)
        if [ "$BATOCERA_MAJOR" -le 41 ]; then
            printf "%-28s %s\n" "Version policy:" "UNSUPPORTED"
            FAIL=1
        else
            printf "%-28s %s\n" "Version policy:" "ALLOWED - UNVERIFIED NEWER VERSION"
        fi
        ;;
esac

if [ -f /userdata/roms/ports/bua.sh ]; then
    printf "%-28s %s\n" "Official BUA:" "DETECTED"
else
    printf "%-28s %s\n" "Official BUA:" "NOT DETECTED"
fi

echo

if [ "$FAIL" -ne 0 ]; then
    echo "[BUA Test] Compatibility check failed."
    echo "[BUA Test] Nothing was installed or modified."
    exit 1
fi

echo "[BUA Test] Preflight passed."
echo
echo "============================================"
echo " Installing BUA Global Updater Test"
echo "============================================"
echo

rm -f "$ARCHIVE" "$CHECKSUM"

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
    rm -f "$ARCHIVE" "$CHECKSUM"
    exit 1
fi

echo "[BUA Test] Checksum verified."

NEW="${INSTALL_ROOT}.new"
OLD="${INSTALL_ROOT}.old"

rm -rf "$NEW" "$OLD"
mkdir -p "$NEW"

if ! tar -xzf "$ARCHIVE" -C "$NEW"; then
    echo "[BUA Test] ERROR: package extraction failed."
    rm -rf "$NEW"
    rm -f "$ARCHIVE" "$CHECKSUM"
    exit 1
fi

if [ ! -f "$NEW/bua_installerx86.py" ] || \
   [ ! -d "$NEW/updater" ]; then

    echo "[BUA Test] ERROR: downloaded package is incomplete."
    rm -rf "$NEW"
    rm -f "$ARCHIVE" "$CHECKSUM"
    exit 1
fi

printf '%s\n' "$ACTUAL" > "$NEW/.bundle.sha256"

cat > "$NEW/.compatibility-info" <<INFO
architecture=$ARCH
batocera_version=$BATOCERA_VERSION
installed_at=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo unknown)
bundle_sha256=$ACTUAL
INFO

if [ -d "$INSTALL_ROOT" ]; then
    mv "$INSTALL_ROOT" "$OLD"
fi

if ! mv "$NEW" "$INSTALL_ROOT"; then
    echo "[BUA Test] ERROR: installation failed."

    rm -rf "$NEW"

    if [ -d "$OLD" ]; then
        mv "$OLD" "$INSTALL_ROOT"
    fi

    rm -f "$ARCHIVE" "$CHECKSUM"
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
echo "Compatibility information:"
cat "$INSTALL_ROOT/.compatibility-info"
echo
