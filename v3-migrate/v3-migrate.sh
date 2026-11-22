#!/bin/bash
# BUA - x86-64-v3 Migration
# Moves a Batocera PC from the x86_64 image (Xorg) to the x86-64-v3 image (Wayland/LabWC)
# and keeps custom setups working:  scan > backup > update > integrate.
# Run it once before the update (scan + backup + prepare) and once after (integrate).
# Source: https://github.com/klova5/batocera-v3-migrate - installs the tool from its latest release.

repo="klova5/batocera-v3-migrate"
fallback_url="https://github.com/$repo/releases/download/v2.0.1/batocera_v3_migrate.py"
APP_DIR="/userdata/system/add-ons/v3-migrate"
TOOL="$APP_DIR/batocera_v3_migrate.py"
LOG="/userdata/system/logs/v3-migrate.log"

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
release_url=$(curl -fsSL --max-time 20 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | python3 -c '
import json, sys
try:
    assets = json.load(sys.stdin).get("assets", [])
except ValueError:
    sys.exit(0)
for a in assets:
    url = a.get("browser_download_url", "")
    if url.endswith("/batocera_v3_migrate.py") and url.startswith("https://github.com/"):
        print(url)
        break
')
if [ -z "$release_url" ]; then
    echo "Could not look up the latest release; using the known release."
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
echo "Installed $TOOL"

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
            dialog --title "x86-64-v3 Migration" --msgbox "Ready for the update.\n\nStart the x86-64-v3 upgrade from Batocera's updates menu, reboot when it asks, then run this add-on again to integrate." 11 64
            exit 0 ;;
        *)
            NEXT="SCAN the system for everything the update affects, BACK UP those things (plus the boot partition for rollback, about 5 GB on /userdata), then PREPARE for the update. The scan can take a few minutes." ;;
    esac
fi

if ! dialog --title "x86-64-v3 Migration" --yesno "Board: $BOARD\n\nNext step:\n$NEXT\n\nEvery file it changes is backed up first.\n\nRun it now?" 16 70; then
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
