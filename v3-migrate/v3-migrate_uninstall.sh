#!/bin/bash
# BUA - x86-64-v3 Migration (uninstall)
# Removes the migration tool. What integrate set up (hook guard, Xwayland access,
# launch watchdog) stays in place, because the system relies on it on x86-64-v3.

APP_DIR="/userdata/system/add-ons/v3-migrate"

echo "## BUA - x86-64-v3 Migration (uninstall)"
rm -rf "$APP_DIR"
dialog --title "x86-64-v3 Migration" --msgbox "The migration tool was removed.\n\nThe fixes it installed stay active (hook guard, Xwayland access, launch watchdog), and your backups stay in /userdata/system/v3-migration." 11 66
exit 0
