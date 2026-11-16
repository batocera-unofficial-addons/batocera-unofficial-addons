#!/bin/bash
# Game Content Manager (GCM) for Batocera: update and DLC management in the game menu.
# Developer preview for Batocera 44 (x86_64). Source: https://github.com/klova5/Game-Content-Manager-GCM-for-Batocera

release_url="https://github.com/klova5/Game-Content-Manager-GCM-for-Batocera/releases/download/v3.6-preview/gcm-v3.6-preview-batocera44-x86_64.zip"
work_dir="/userdata/system/add-ons/game-content-manager/release"

if [ "$(uname -m)" != "x86_64" ]; then
    echo "GCM is only available for x86_64 Batocera."
    exit 1
fi

echo "Downloading Game Content Manager..."
rm -rf "$work_dir"
mkdir -p "$work_dir"
if ! wget -q --show-progress -O "$work_dir/gcm.zip" "$release_url"; then
    echo "Download failed."
    exit 1
fi

echo "Unpacking..."
unzip -q "$work_dir/gcm.zip" -d "$work_dir" && rm -f "$work_dir/gcm.zip"

echo "Checking this device..."
if ! bash "$work_dir/gcm-v3.6-preview/install.sh" --check; then
    echo "GCM was not installed."
    exit 1
fi

echo "Installing..."
if ! bash "$work_dir/gcm-v3.6-preview/install.sh"; then
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
