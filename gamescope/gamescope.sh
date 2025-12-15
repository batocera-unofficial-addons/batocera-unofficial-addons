#!/bin/bash
#=======================================================================
# Special thanks to Redemp/Rion and Spirit(RGS) for providing Gamescope
#=======================================================================

set -e

GAMESCOPE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/gamescope/extra/gamescope.tar.gz"
DEST_DIR="/userdata/system"
TAR_PATH="${DEST_DIR}/gamescope.tar.gz"
EXTRACT_DIR="${DEST_DIR}/gamescope"

echo "== Downloading gamescope.tar.gz =="
mkdir -p "$DEST_DIR"

wget -q --show-progress -c -O "$TAR_PATH" "$GAMESCOPE_URL"

echo "== Removing old extracted directory =="
rm -rf "$EXTRACT_DIR"

echo "== Extracting archive =="
tar -xzf "$TAR_PATH" -C "$DEST_DIR"

INSTALL_SCRIPT="${EXTRACT_DIR}/install_gamescope_v42.sh"
UNINSTALL_SCRIPT="${EXTRACT_DIR}/uninstall_gamescope_v42.sh"

echo "== Setting executable permissions =="
chmod +x "$INSTALL_SCRIPT"
chmod +x "$UNINSTALL_SCRIPT"

echo "== Running installer =="
bash "$INSTALL_SCRIPT"

echo "== Gamescope v42 Installed Successfully =="
