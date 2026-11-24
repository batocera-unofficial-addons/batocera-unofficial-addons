#!/bin/bash
# BUA - x86-64-v3 Migration
# Moves a Batocera PC from the x86_64 image (Xorg) to the x86-64-v3 image (Wayland/LabWC)
# and keeps custom setups working:  scan > backup > update > integrate.
# Run it once before the update (scan + backup + prepare) and once after (integrate).
# Source: https://github.com/klova5/batocera-wayland-v3-migrate - installs the tool from its latest release.

repo="klova5/batocera-wayland-v3-migrate"
fallback_tag="v2.1.0"
fallback_url="https://github.com/$repo/releases/download/$fallback_tag/batocera_v3_migrate.py"
APP_DIR="/userdata/system/add-ons/v3-migrate"
TOOL="$APP_DIR/batocera_v3_migrate.py"
LOG="/userdata/system/logs/v3-migrate.log"
version_file="$APP_DIR/bua-version.json"

# The latest release: tag, a fingerprint of the release and its files (BUA's update identity), and the
# tool's download URL. Prints nothing if GitHub cannot be asked.
v3m_latest_release() {
    curl -fsSL --max-time 20 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | python3 -c '
import hashlib, json, sys
try:
    release = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
tag = str(release.get("tag_name") or "").strip()
assets = release.get("assets") or []
url = next((a.get("browser_download_url", "") for a in assets
            if a.get("browser_download_url", "").endswith("/batocera_v3_migrate.py")
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

# BUA updater: report the installed tool version (from bua-version.json) and the latest release.
v3m_bua_register() {
    declare -F bua_register >/dev/null 2>&1 || return 0
    bua_register "$1" "github_release" "klova5" "batocera-wayland-v3-migrate" "reinstall" \
        "json" "$version_file" "version" "$2"
}

# The BUA updater asks for the latest version this way; nothing is installed.
if [ "${BUA_REGISTRATION_ONLY:-0}" = "1" ]; then
    latest=$(v3m_latest_release)
    [ -n "$latest" ] || { echo "Could not look up the latest migration tool release." >&2; exit 1; }
    v3m_bua_register "$(echo "$latest" | sed -n 1p)" "$(echo "$latest" | sed -n 2p)"
    exit $?
fi

echo "## BUA - x86-64-v3 Migration"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: must be run as root."
    exit 1
fi

BOARD="$(cat /boot/boot/batocera.board 2>/dev/null)"
case "$BOARD" in
    x86_64|x86-64-v3) ;;
    *)
        dialog --title "x86-64-v3 Migration" --msgbox "This add-on is for Batocera on PCs (x86_64 or x86-64-v3).\n\nThis system is: ${BOARD:-unknown}" 9 60
        exit 0
        ;;
esac

# === Download the tool: the latest release; the known release if GitHub cannot be asked ===
latest=$(v3m_latest_release)
release_tag=$(echo "$latest" | sed -n 1p)
release_identity=$(echo "$latest" | sed -n 2p)
release_url=$(echo "$latest" | sed -n 3p)
if [ -z "$release_url" ]; then
    echo "Could not look up the latest release; using the known release."
    release_tag="$fallback_tag"
    release_identity="$fallback_tag"
    release_url="$fallback_url"
fi

mkdir -p "$APP_DIR" /userdata/system/logs
echo "Downloading the migration tool: $release_url"
if ! curl -fsSL "$release_url" -o "$TOOL.new" || ! python3 -m py_compile "$TOOL.new" 2>/dev/null; then
    rm -f "$TOOL.new"
    dialog --title "x86-64-v3 Migration" --msgbox "Could not download the migration tool. Check the network and try again." 8 60
    exit 1
fi
mv -f "$TOOL.new" "$TOOL"
chmod +x "$TOOL"
echo "Installed $TOOL ($release_tag)"

# Record the installed release for BUA's updater (shown as the app version).
python3 -c 'import json, sys; json.dump({"version": sys.argv[1], "update_identity": sys.argv[2]}, open(sys.argv[3], "w"), indent=1)' \
    "$release_tag" "$release_identity" "$version_file"
v3m_bua_register "$release_tag" "$release_identity" || true

# === Ports entry: "V3 Migration" opens a controller menu for every step (tool v2.1.0+) ===
if python3 "$TOOL" launcher install >>"$LOG" 2>&1; then
    PORTS_NOTE="\n\nTip: Ports > V3 Migration runs every step with a controller, and can cancel a step and put back what it changed."
else
    PORTS_NOTE=""
fi

# === Work out the next step ===
PHASE="$(python3 - <<'PY'
import json
try:
    print(json.load(open("/userdata/system/v3-migration/state.json")).get("phase", ""))
except Exception:
    print("")
PY
)"

if [ "$BOARD" = "x86-64-v3" ]; then
    case "$PHASE" in
        integrated*)
            NEXT="Integrate again (safe to repeat): re-checks everything and fixes anything new." ;;
        *)
            NEXT="INTEGRATE: put everything the update affected back with full functionality (hooks, Xwayland access, services, overlay files, display output), and install the launch watchdog and rescue combo." ;;
    esac
else
    case "$PHASE" in
        prepared)
            dialog --title "x86-64-v3 Migration" --msgbox "Ready for the update.\n\nStart the x86-64-v3 upgrade from Batocera's updates menu, reboot when it asks, then run this add-on again (or Ports > V3 Migration) to integrate." 12 64
            exit 0 ;;
        *)
            NEXT="SCAN the system for everything the update affects, BACK UP those things (plus the boot partition for rollback, about 5 GB on /userdata), then PREPARE for the update. The scan can take a few minutes." ;;
    esac
fi

if ! dialog --title "x86-64-v3 Migration" --yesno "Board: $BOARD\n\nNext step:\n$NEXT\n\nEvery file it changes is backed up first.$PORTS_NOTE\n\nRun it now?" 19 70; then
    echo "Nothing changed. Run this add-on again whenever you're ready."
    echo "Advanced (SSH): python3 $TOOL --help"
    exit 0
fi

echo "Running... (log: $LOG)"
python3 "$TOOL" --yes 2>&1 | tee -a "$LOG"
RC=${PIPESTATUS[0]}

SUMMARY="$(tail -n 14 "$LOG" | cut -c1-90)"
if [ "$RC" -eq 0 ]; then
    dialog --title "x86-64-v3 Migration" --msgbox "Done.\n\n$SUMMARY\n\nFull log: $LOG" 24 96
else
    dialog --title "x86-64-v3 Migration" --msgbox "Stopped (code $RC). Nothing after the problem was changed.\n\n$SUMMARY\n\nFull log: $LOG" 24 96
fi
exit 0
