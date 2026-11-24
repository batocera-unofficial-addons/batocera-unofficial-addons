#!/bin/bash
# BUA - x86-64-v3 Migration (uninstall)
# Removes the migration tool. What integrate set up (hook guard, Xwayland access,
# launch watchdog) stays in place, because the system relies on it on x86-64-v3.

APP_DIR="/userdata/system/add-ons/v3-migrate"

echo "## BUA - x86-64-v3 Migration (uninstall)"

# Remove the Ports entry, but only the one this add-on installed (it runs the tool from $APP_DIR)
PORT="/userdata/roms/ports/V3 Migration.sh"
WHAT="The migration tool was removed."
if grep -q '^# v3-migrate-launcher' "$PORT" 2>/dev/null && grep -q "^TOOL=$APP_DIR/" "$PORT"; then
    rm -f "$PORT" "$PORT.keys"
    curl -s -m 5 http://127.0.0.1:1234/reloadgames >/dev/null 2>&1
    echo "Removed the V3 Migration entry from Ports"
    WHAT="The migration tool and its Ports entry were removed."
fi

rm -rf "$APP_DIR"
dialog --title "x86-64-v3 Migration" --msgbox "$WHAT\n\nThe fixes it installed stay active (hook guard, Xwayland access, launch watchdog), and your backups stay in /userdata/system/v3-migration." 11 66
exit 0
