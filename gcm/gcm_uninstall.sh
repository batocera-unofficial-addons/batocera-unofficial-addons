#!/bin/bash
# Uninstall Game Content Manager (GCM). Games, saves and emulator settings are kept.

repo="klova5/Game-Content-Manager-GCM-for-Batocera"
fallback_url="https://github.com/$repo/releases/download/GCM-v4.0-preview-1/gcm-v4.0-preview-1-batocera44-x86_64.zip"
work_dir="/userdata/system/add-ons/game-content-manager/release"

uninstaller=$(ls -d "$work_dir"/*/uninstall.sh 2>/dev/null | head -1)
if [ -z "$uninstaller" ]; then
    # The downloaded release is gone: fetch the latest one for its uninstaller.
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
    [ -z "$release_url" ] && release_url="$fallback_url"
    mkdir -p "$work_dir"
    wget -q --show-progress -O "$work_dir/gcm.zip" "$release_url" && unzip -q -o "$work_dir/gcm.zip" -d "$work_dir" && rm -f "$work_dir/gcm.zip"
    uninstaller=$(ls -d "$work_dir"/*/uninstall.sh 2>/dev/null | head -1)
fi

if [ -z "$uninstaller" ] || ! bash "$uninstaller"; then
    echo "GCM uninstall did not complete."
    exit 1
fi
batocera-services disable GCMV36 >/dev/null 2>&1
rm -rf "$work_dir"
rm -f /userdata/system/add-ons/game-content-manager/bua-version.json
echo "Game Content Manager removed. The standard frontend is in use."
