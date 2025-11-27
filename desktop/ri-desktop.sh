#!/bin/bash
set -euo pipefail

###############################################################################
# RunImage Desktop Installer for Batocera
###############################################################################

echo "==================================================================="
echo "RunImage Desktop Installer"
echo "==================================================================="

# Detect system architecture
echo "[*] Detecting system architecture..."
arch=$(uname -m)

case "$arch" in
    aarch64|armv8*|arm64)
        echo "    Architecture: ARM64/aarch64 detected"
        OVERLAY_PACKAGE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages/ri-desktop-arm64.tar.xz"
        ;;
    *)
        echo "[!] Error: This installer currently only supports ARM64/aarch64 architecture"
        echo "    Detected architecture: $arch"
        echo "    Support for other architectures coming soon!"
        exit 1
        ;;
esac

# Download overlay package
TEMP_PACKAGE="/tmp/ri-desktop-overlay.tar.xz"

echo "[*] Downloading RunImage Desktop package..."
echo "    URL: ${OVERLAY_PACKAGE_URL}"
if command -v wget >/dev/null 2>&1; then
    wget -q --show-progress -O "${TEMP_PACKAGE}" "${OVERLAY_PACKAGE_URL}"
elif command -v curl >/dev/null 2>&1; then
    curl -L -o "${TEMP_PACKAGE}" "${OVERLAY_PACKAGE_URL}"
else
    echo "[!] Error: Neither wget nor curl found!"
    exit 1
fi

# Extract overlay package to /userdata/system/add-ons
echo "[*] Extracting package to /userdata/system/add-ons..."
cd /userdata/system/add-ons
tar -xJf "${TEMP_PACKAGE}"

# Clean up temporary file
rm -f "${TEMP_PACKAGE}"

# Create launcher script
echo "[*] Creating launcher script..."
LAUNCHER_PATH="/userdata/system/add-ons/ri-desktop/launcher.sh"

cat > "${LAUNCHER_PATH}" << 'LAUNCHER_EOF'
#!/bin/bash
set -euo pipefail

###############################################################################
# Configuration
###############################################################################

DEST_BASE="/userdata/system/add-ons/ri-desktop"
BIN_PATH="${DEST_BASE}/runimage"
OVERLAY_DIR="${DEST_BASE}/overlays"
CACHE_DIR="${DEST_BASE}/cache"
RUNTIME_DIR="${DEST_BASE}/runtime"
OVERFS_ID="desktop"
DISPLAY_VAR=":0.0"

LOGFILE="${DEST_BASE}/overlay.log"
LOCKFILE="${DEST_BASE}/${OVERFS_ID}.lock"

###############################################################################
# Helper functions
###############################################################################

AcquireLock() {
  if [ -f "${LOCKFILE}" ]; then
    # Check for a still-running RunImage desktop session
    if pgrep -f "${BIN_PATH}.*rim-desktop" >/dev/null 2>&1 || \
       pgrep -f "Xephyr .*rim-desktop" >/dev/null 2>&1; then
      echo "[i] RunImage desktop '${OVERFS_ID}' already running. Exiting."
      exit 0
    else
      echo "[i] Stale lockfile found for '${OVERFS_ID}'. Removing."
      rm -f "${LOCKFILE}"
    fi
  fi

  touch "${LOCKFILE}"
  # Always clean up the lockfile on exit or interrupt
  trap 'rm -f "${LOCKFILE}"' EXIT INT TERM
}

EnsureFuse() {
  # Inline version of your check_fuse.sh
  if [ ! -e /dev/fuse ]; then
    modprobe fuse 2>/dev/null || true
    [ -e /dev/fuse ] || mknod /dev/fuse -m 0666 c 10 229 || true
  fi
}

FuseAvailable() {
  [ -c /dev/fuse ] && [ -r /dev/fuse ]
}

###############################################################################
# RunImage launchers
###############################################################################

LaunchOverlay() {
  {
    echo "==== $(date) ===="
    echo "Launching overlay mode"
    echo "OVERFS_ID=${OVERFS_ID}"
    echo "OVERLAY_DIR=${OVERLAY_DIR}"
    echo "CACHE_DIR=${CACHE_DIR}"
    echo "BIN_PATH=${BIN_PATH}"
    echo "DISPLAY=${DISPLAY_VAR}"
    echo "-------------------------------------------------------------"

    env \
      RIM_OVERFS_ID="${OVERFS_ID}" \
      RIM_KEEP_OVERFS=1 \
      RIM_UNSHARE_HOME=1 \
      RIM_BIND="/userdata:/userdata,/media:/media" \
      RIM_OVERFSDIR="${OVERLAY_DIR}" \
      RIM_CACHEDIR="${CACHE_DIR}" \
      RIM_ALLOW_ROOT=1 DISPLAY="${DISPLAY_VAR}" \
      RIM_XEPHYR_FULLSCREEN=1 \
      "${BIN_PATH}" rim-desktop

    rc=$?
    echo "-------------------------------------------------------------"
    echo "Overlay mode terminated with exit code ${rc}"
    echo
    return "${rc}"
  } 2>&1 | tee -a "${LOGFILE}"
}

LaunchUnpacked() {
  {
    echo "==== $(date) ===="
    echo "Launching unpacked mode"
    echo "RUNTIME_DIR=${RUNTIME_DIR}"
    echo "-------------------------------------------------------------"

    env \
      URUNTIME_TARGET_DIR="${RUNTIME_DIR}" \
      TMPDIR="${RUNTIME_DIR}" \
      RUNTIME_EXTRACT_AND_RUN=1 \
      NO_CLEANUP=1 \
      RIM_UNSHARE_HOME=1 \
      RIM_BIND="/userdata:/userdata,/media:/media" \
      RIM_ALLOW_ROOT=1 DISPLAY="${DISPLAY_VAR}" \
      "${BIN_PATH}" rim-desktop

    rc=$?
    echo "-------------------------------------------------------------"
    echo "Unpacked mode terminated with exit code ${rc}"
    echo
    return "${rc}"
  } 2>&1 | tee -a "${LOGFILE}"
}

###############################################################################
# Main
###############################################################################

Main() {
  mkdir -p "${OVERLAY_DIR}" "${CACHE_DIR}" "${RUNTIME_DIR}"
  touch "${LOGFILE}"

  AcquireLock
  EnsureFuse

  # If FUSE really isn't available, go straight to unpacked mode.
  if ! FuseAvailable; then
    echo "[!] /dev/fuse not available. Using unpacked extract-and-run mode."
    echo "[!] See log: ${LOGFILE}"
    LaunchUnpacked
    exit $?
  fi

  set +e
  LaunchOverlay
  rc=$?
  set -e

  case "${rc}" in
    0)
      # Clean exit
      exit 0
      ;;
    1)
      # Generic non-zero from the session; fine for this use-case
      echo "[i] Overlay session ended with exit code 1 (treating as normal)."
      exit 0
      ;;
    130|143)
      # Ctrl+C (130) or SIGTERM (143) – both are normal user/host-driven exits
      echo "[i] Overlay session terminated by signal (exit ${rc}, treating as normal)."
      exit 0
      ;;
    *)
      echo "[!] Overlay mode failed with exit code ${rc}"
      echo "[i] FUSE exists, so this is *not* a FUSE error."
      echo "[i] Likely causes:"
      echo "    - overlay still busy from previous run"
      echo "    - corrupted overlay dir"
      echo "    - X/display error"
      echo "    - rim-desktop crashed"
      echo "[i] See full log at: ${LOGFILE}"
      exit "${rc}"
      ;;
  esac
}

Main "$@"
LAUNCHER_EOF

chmod +x "${LAUNCHER_PATH}"

# Create EmulationStation port entry
echo "[*] Creating EmulationStation port entry..."
PORTS_DIR="/userdata/roms/ports"
PORT_SCRIPT="${PORTS_DIR}/RunImageDesktop.sh"

mkdir -p "${PORTS_DIR}"

cat > "${PORT_SCRIPT}" << 'PORT_EOF'
#!/bin/bash
/userdata/system/add-ons/ri-desktop/launcher.sh
PORT_EOF

chmod +x "${PORT_SCRIPT}"

# Create pad2key profile
echo "[*] Creating pad2key profile..."
PAD2KEY_PROFILE="${PORTS_DIR}/RunImageDesktop.sh.keys"

cat > "${PAD2KEY_PROFILE}" << 'PAD2KEY_EOF'
{
    "actions_player1": [
        {
            "trigger": "joystick2",
            "type": "mouse"
        },
        {
            "trigger": "r3",
            "type": "key",
            "target": "BTN_LEFT"
        },
        {
            "trigger": "l3",
            "type": "key",
            "target": "BTN_RIGHT"
        },
        {
            "trigger": "up",
            "type": "key",
            "target": "KEY_UP"
        },
        {
            "trigger": "down",
            "type": "key",
            "target": "KEY_DOWN"
        },
        {
            "trigger": "left",
            "type": "key",
            "target": "KEY_LEFT"
        },
        {
            "trigger": "right",
            "type": "key",
            "target": "KEY_RIGHT"
        },
        {
            "trigger": "joystick1up",
            "type": "key",
            "target": "KEY_PAGEUP"
        },
        {
            "trigger": "joystick1down",
            "type": "key",
            "target": "KEY_PAGEDOWN"
        }
    ]
}
PAD2KEY_EOF

# Download images
echo "[*] Downloading images..."
mkdir -p "${PORTS_DIR}/images"
curl -L -o "${PORTS_DIR}/images/desktop-logo.png" \
  "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/desktop/extra/desktop-logo.png" 2>/dev/null || true
curl -L -o "${PORTS_DIR}/images/desktop-marquee.png" \
  "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/desktop/extra/desktop-marquee.png" 2>/dev/null || true

# Add entry to gamelist.xml with xmlstarlet
echo "[*] Adding entry to gamelist.xml..."
if [ -f /userdata/roms/ports/gamelist.xml ]; then
    xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
      -s "/gameList/game[last()]" -t elem -n "path" -v "./RunImageDesktop.sh" \
      -s "/gameList/game[last()]" -t elem -n "name" -v "RunImage Desktop" \
      -s "/gameList/game[last()]" -t elem -n "image" -v "./images/desktop-logo.png" \
      -s "/gameList/game[last()]" -t elem -n "marquee" -v "./images/desktop-marquee.png" \
      /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && \
      mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml
fi

# Refresh EmulationStation game list
echo "[*] Refreshing EmulationStation..."
curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1 || true

echo ""
echo "==================================================================="
echo "RunImage Desktop installed successfully!"
echo "==================================================================="
echo ""
echo "Launch from: Ports > RunImage Desktop"
echo ""
echo "Installation location: /userdata/system/add-ons/ri-desktop"
echo "Log file: /userdata/system/add-ons/ri-desktop/overlay.log"
echo ""
echo "==================================================================="
