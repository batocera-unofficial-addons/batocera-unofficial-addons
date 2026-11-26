#!/bin/bash
# Native Desktop — auto-detect X11 (Openbox) or Wayland (labwc) and
# install the correct desktop variant.

REPO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main"

if pgrep -x labwc >/dev/null 2>&1; then
    dialog --title "Native Desktop" --infobox "Wayland detected — installing Native Wayland Desktop." 5 60
    curl -fsSL "$REPO_URL/native-wayland-desktop/native-wayland-desktop.sh" | bash
    exit "${PIPESTATUS[1]}"
else
    dialog --title "Native Desktop" --infobox "X11 detected — installing Native X11 Desktop." 5 60
    curl -fsSL "$REPO_URL/native-desktop/native-x11-desktop.sh" | bash
    exit "${PIPESTATUS[1]}"
fi
