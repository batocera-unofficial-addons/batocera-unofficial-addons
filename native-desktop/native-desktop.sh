#!/bin/bash
# Native Desktop — auto-detect X11 (Openbox) or Wayland (labwc) and
# install the correct desktop variant.
# Also cleans up old squashfs-based desktop installs before proceeding.

REPO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main"

# --- Cleanup old desktop installs ---
# Light Desktop, Desktop for Batocera (squashfs / reworked DRL) and the
# original DRL desktop. Shared with native-desktop_uninstall.sh; the Docker
# "Desktop" add-on is never touched.
cleanup_script=$(mktemp)
if ! curl -fsSL -o "$cleanup_script" "$REPO_URL/native-desktop/native-desktop-legacy-cleanup.sh"; then
    rm -f "$cleanup_script"
    dialog --title "Native Desktop" --msgbox "Failed to download the cleanup for older desktops. Check your connection and try again." 10 60
    exit 1
fi
bash "$cleanup_script" install
rm -f "$cleanup_script"

# --- Route to the correct variant ---

if pgrep -x labwc >/dev/null 2>&1; then
    dialog --title "Native Desktop" --infobox "Wayland detected — installing Native Wayland Desktop." 5 60
    curl -fsSL "$REPO_URL/native-wayland-desktop/native-wayland-desktop.sh" | bash
    exit "${PIPESTATUS[1]}"
else
    dialog --title "Native Desktop" --infobox "X11 detected — installing Native X11 Desktop." 5 60
    curl -fsSL "$REPO_URL/native-desktop/native-x11-desktop.sh" | bash
    exit "${PIPESTATUS[1]}"
fi
