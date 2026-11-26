#!/bin/bash
# Native Desktop — auto-detect X11 (Openbox) or Wayland (labwc) and
# install the correct desktop variant.
# Also cleans up old squashfs-based desktop installs before proceeding.

REPO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main"

# --- Cleanup old desktop installs ---

# Old squashfs-based "desktop" service (DRL / Desktop for Batocera)
if [ -f /userdata/system/services/desktop ]; then
    echo "Removing old squashfs desktop service..."
    batocera-services stop desktop 2>/dev/null
    batocera-services disable desktop 2>/dev/null
    rm -f /userdata/system/services/desktop
fi

# Old squashfs rootfs at /userdata/system/add-ons/desktop
if [ -d /userdata/system/add-ons/desktop/rootfs ]; then
    echo "Removing old squashfs desktop addon..."
    rm -rf /userdata/system/add-ons/desktop
fi

# Old squashfs rootfs at native-x11-desktop (from the transitional commit)
if [ -d /userdata/system/add-ons/native-x11-desktop/rootfs ]; then
    echo "Removing old squashfs native-x11-desktop addon..."
    batocera-services stop native-x11-desktop 2>/dev/null
    batocera-services disable native-x11-desktop 2>/dev/null
    rm -rf /userdata/system/add-ons/native-x11-desktop
    rm -f /userdata/system/services/native-x11-desktop
fi

# Old DRL desktop
if [ -d /userdata/system/add-ons/desktop_drl ]; then
    echo "Removing old DRL desktop addon..."
    rm -rf /userdata/system/add-ons/desktop_drl
    rm -f /userdata/system/services/desktop_drl
fi
if [ -f /userdata/system/configs/bat-drl/Remover_Desktop.sh ]; then
    echo "Running DRL desktop remover..."
    function yad() { return 0; }; export -f yad
    bash /userdata/system/configs/bat-drl/Remover_Desktop.sh 2>/dev/null
    unset -f yad
fi

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
