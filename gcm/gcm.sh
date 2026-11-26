#!/bin/bash
# Game Content Manager (GCM) for Batocera: update and DLC management in the game menu.
# For Batocera 44 (x86_64). Source: https://github.com/klova5/Game-Content-Manager-GCM-for-Batocera
#
# Installs the latest GCM release (the same release BUA's updater reports), and updates an existing GCM
# in place: only GCM's program files are replaced; its settings, state and game content are kept.

repo="klova5/Game-Content-Manager-GCM-for-Batocera"
fallback_tag="GCM-v4.0-preview-1"
fallback_url="https://github.com/$repo/releases/download/$fallback_tag/gcm-v4.0-preview-1-batocera44-x86_64.zip"
gcm_dir="/userdata/system/add-ons/game-content-manager"
work_dir="$gcm_dir/release"
version_file="$gcm_dir/bua-version.json"

# The latest release: tag, a fingerprint of the release and its files (BUA's update identity), and the
# x86_64 zip. Prints nothing if GitHub cannot be asked.
gcm_latest_release() {
    curl -fsSL --max-time 20 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | python3 -c '
import hashlib, json, sys
try:
    release = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
tag = str(release.get("tag_name") or "").strip()
assets = release.get("assets") or []
url = next((a.get("browser_download_url", "") for a in assets
            if a.get("browser_download_url", "").endswith("-batocera44-x86_64.zip")
            and a.get("browser_download_url", "").startswith("https://github.com/")), "")
if not tag or not url:
    sys.exit(0)
files = sorted((str(a.get("name")), str(a.get("id")), str(a.get("size")), str(a.get("updated_at"))) for a in assets)
digest = hashlib.sha256(json.dumps([release.get("id"), files]).encode()).hexdigest()
print(tag)
print("github-release:%s:%s" % (release.get("id"), digest))
print(url)
'
}

# BUA updater: report the installed GCM version (from bua-version.json) and the latest release.
gcm_bua_register() {
    declare -F bua_register >/dev/null 2>&1 || return 0
    bua_register "$1" "github_release" "klova5" "Game-Content-Manager-GCM-for-Batocera" "reinstall" \
        "json" "$version_file" "version" "$2"
}

# The BUA updater asks for the latest version this way; nothing is installed.
if [ "${BUA_REGISTRATION_ONLY:-0}" = "1" ]; then
    latest=$(gcm_latest_release)
    [ -n "$latest" ] || { dialog --title "GCM" --msgbox "Could not look up the latest GCM release." 8 60; exit 1; }
    gcm_bua_register "$(echo "$latest" | sed -n 1p)" "$(echo "$latest" | sed -n 2p)"
    exit $?
fi

if [ "$(uname -m)" != "x86_64" ]; then
    dialog --title "GCM" --msgbox "GCM is only available for x86_64 Batocera." 8 60
    exit 1
fi

# The latest release; the known release if GitHub cannot be asked.
latest=$(gcm_latest_release)
release_tag=$(echo "$latest" | sed -n 1p)
release_identity=$(echo "$latest" | sed -n 2p)
release_url=$(echo "$latest" | sed -n 3p)
if [ -z "$release_url" ]; then
    echo "Could not look up the latest GCM release; using the known release."
    release_tag="$fallback_tag"
    release_identity="$fallback_tag"
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
    dialog --title "GCM" --msgbox "Download failed." 8 60
    exit 1
fi

echo "Unpacking..."
if ! unzip -q "$work_dir/gcm.zip" -d "$work_dir"; then
    dialog --title "GCM" --msgbox "The download is damaged; GCM was not installed." 8 60
    exit 1
fi
rm -f "$work_dir/gcm.zip"
installer=$(ls -d "$work_dir"/*/install.sh 2>/dev/null | head -1)
if [ -z "$installer" ]; then
    dialog --title "GCM" --msgbox "The release has no installer; GCM was not installed." 8 60
    exit 1
fi

echo "Checking this device..."
if ! bash "$installer" --check; then
    dialog --title "GCM" --msgbox "GCM was not installed." 8 60
    exit 1
fi

echo "Installing..."
if ! bash "$installer" $replace; then
    dialog --title "GCM" --msgbox "GCM was not installed." 8 60
    exit 1
fi

# Start GCM at every boot (it replaces the standard frontend after startup; switch back any time).
batocera-services enable GCMV36

# Record the installed release for BUA's updater (shown as the app version).
python3 -c 'import json, sys; json.dump({"version": sys.argv[1], "update_identity": sys.argv[2]}, open(sys.argv[3], "w"), indent=1)' \
    "$release_tag" "$release_identity" "$version_file"
gcm_bua_register "$release_tag" "$release_identity" || true
echo "GCM version: $release_tag"

echo
echo "Game Content Manager installed. It starts after the next reboot."
echo "Switch frontends any time:"
echo "  python3 /userdata/system/add-ons/game-content-manager/v36-permanent/gcm-frontend-switch.py v36   (GCM)"
echo "  python3 /userdata/system/add-ons/game-content-manager/v36-permanent/gcm-frontend-switch.py v34   (standard)"
