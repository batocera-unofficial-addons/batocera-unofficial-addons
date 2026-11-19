#!/bin/bash
# Game Content Manager (GCM) for Batocera: update and DLC management in the game menu.
# Developer preview for Batocera 44 (x86_64). Source: https://github.com/klova5/Game-Content-Manager-GCM-for-Batocera
#
# Installs the latest GCM release (the same release BUA's updater reports), and updates an existing GCM
# in place: only GCM's program files are replaced; its settings, state and game content are kept.

repo="klova5/Game-Content-Manager-GCM-for-Batocera"
fallback_url="https://github.com/$repo/releases/download/GCM-v3.6-preview-4/gcm-v3.6-preview-4-batocera44-x86_64.zip"
gcm_dir="/userdata/system/add-ons/game-content-manager"
work_dir="$gcm_dir/release"

if [ "$(uname -m)" != "x86_64" ]; then
    echo "GCM is only available for x86_64 Batocera."
    exit 1
fi

# The latest release's x86_64 zip; the known release if GitHub cannot be asked.
release_url=$(curl -fsSL --max-time 20 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | python3 -c '
import json, sys
try:
    assets = json.load(sys.stdin).get("assets", [])
except ValueError:
    sys.exit(0)
for a in assets:
    url = a.get("browser_download_url", "")
    if url.endswith("-batocera44-x86_64.zip") and url.startswith("https://github.com/"):
        print(url)
        break
')
if [ -z "$release_url" ]; then
    echo "Could not look up the latest GCM release; using the known release."
    release_url="$fallback_url"
fi

# An existing GCM is updated in place.
replace=""
if [ -f "$gcm_dir/release-install.json" ] || [ -f "$gcm_dir/v36-permanent/deployment.json" ]; then
    replace="--replace"
    echo "Existing GCM found: it will be updated."
fi

echo "Downloading Game Content Manager: ${release_url##*/}"
rm -rf "$work_dir"
mkdir -p "$work_dir"
if ! wget -q --show-progress -O "$work_dir/gcm.zip" "$release_url"; then
    echo "Download failed."
    exit 1
fi

echo "Unpacking..."
if ! unzip -q "$work_dir/gcm.zip" -d "$work_dir"; then
    echo "The download is damaged; GCM was not installed."
    exit 1
fi
rm -f "$work_dir/gcm.zip"
installer=$(ls -d "$work_dir"/*/install.sh 2>/dev/null | head -1)
if [ -z "$installer" ]; then
    echo "The release has no installer; GCM was not installed."
    exit 1
fi

echo "Checking this device..."
if ! bash "$installer" --check; then
    echo "GCM was not installed."
    exit 1
fi

echo "Installing..."
if ! bash "$installer" $replace; then
    echo "GCM was not installed."
    exit 1
fi

# Start GCM at every boot (it replaces the standard frontend after startup; switch back any time).
batocera-services enable GCMV36

echo
echo "Game Content Manager installed. It starts after the next reboot."
echo "Switch frontends any time:"
echo "  python3 /userdata/system/add-ons/game-content-manager/v36-permanent/gcm-frontend-switch.py v36   (GCM)"
echo "  python3 /userdata/system/add-ons/game-content-manager/v36-permanent/gcm-frontend-switch.py v34   (standard)"
