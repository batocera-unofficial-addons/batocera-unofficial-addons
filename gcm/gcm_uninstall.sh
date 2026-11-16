#!/bin/bash
# Uninstall Game Content Manager (GCM). Games, saves and emulator settings are kept.

work_dir="/userdata/system/add-ons/game-content-manager/release"
release_url="https://github.com/klova5/Game-Content-Manager-GCM-for-Batocera/releases/download/v3.6-preview/gcm-v3.6-preview-batocera44-x86_64.zip"

if [ ! -f "$work_dir/gcm-v3.6-preview/uninstall.sh" ]; then
    mkdir -p "$work_dir"
    wget -q --show-progress -O "$work_dir/gcm.zip" "$release_url" && unzip -q -o "$work_dir/gcm.zip" -d "$work_dir" && rm -f "$work_dir/gcm.zip"
fi

if ! bash "$work_dir/gcm-v3.6-preview/uninstall.sh"; then
    echo "GCM uninstall did not complete."
    exit 1
fi
batocera-services disable GCMV36 >/dev/null 2>&1
rm -rf "$work_dir"
echo "Game Content Manager removed. The standard frontend is in use."
