#!/bin/bash
# Installer for the Native X11 Desktop. Called by native-desktop.sh
# (the unified BUA entry) when X11 (Openbox) is detected, or directly.
#
# It provides a desktop with a taskbar, app menu, desktop icons, dark mode,
# and movable/resizable windows, running within Batocera's Openbox session.
# Everything it uses is already part of Batocera (Openbox, GTK, PCManFM,
# xterm, wmctrl), so the add-on itself is under 1 MB and nothing else is
# downloaded. F1 opens the desktop; Hotkey+Start returns to EmulationStation.
#
# F1 opens whichever desktop was installed last: installing this one takes F1
# over from other desktops, and installing another gives it back.

APPNAME="Native X11 Desktop"
install_dir="/userdata/system/add-ons/native-x11-desktop"
ports_dir="/userdata/roms/ports"
port_script="$ports_dir/Native X11 Desktop.sh"
service_file="/userdata/system/services/native-x11-desktop"
base_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/native-desktop"

fail() {
    dialog --title "$APPNAME" --msgbox "$1" 10 60
    exit 1
}

# Requires X11 (Openbox)
pgrep -x openbox >/dev/null || fail "$APPNAME needs Batocera's X11 desktop (Openbox), not Wayland (labwc)."

echo "Installing $APPNAME..."
mkdir -p "$install_dir/config"

echo "Downloading $APPNAME..."
for f in native-x11-desktop-launch.sh native-x11-desktop-session.sh native-x11-desktop-exit.sh \
         native-x11-desktop-panel.py native-x11-desktop-desktop.py native-x11-desktop-service \
         native-x11-desktop-logo.png wallpaper.png; do
    wget -q --show-progress -O "$install_dir/$f.tmp" "$base_url/extra/$f" || fail "Failed to download $f."
    mv -f "$install_dir/$f.tmp" "$install_dir/$f"
done
for f in rc.xml menu.xml; do
    wget -q --show-progress -O "$install_dir/config/$f.tmp" "$base_url/extra/config/$f" || fail "Failed to download config/$f."
    mv -f "$install_dir/config/$f.tmp" "$install_dir/config/$f"
done
chmod +x "$install_dir"/*.sh "$install_dir"/*.py "$install_dir/native-x11-desktop-service"

# F1 opens the Native X11 Desktop: a Batocera service, enabled at boot.
# The last desktop installed gets F1, so competing desktop services are
# stopped and switched off (the addons themselves stay installed).
echo "Setting up F1..."
if [ -f /userdata/system/services/native-wayland-desktop ]; then
    bash /userdata/system/services/native-wayland-desktop stop >/dev/null 2>&1
    batocera-services disable native-wayland-desktop >/dev/null 2>&1
    echo "F1 now opens the Native X11 Desktop instead of Native Wayland Desktop."
fi
if [ -f /userdata/system/services/kdeplasma ]; then
    bash /userdata/system/services/kdeplasma stop >/dev/null 2>&1
    batocera-services disable kdeplasma >/dev/null 2>&1
    echo "F1 now opens the Native X11 Desktop instead of KDE Plasma (Plasma is still in Ports)."
fi
mkdir -p /userdata/system/services
cp -f "$install_dir/native-x11-desktop-service" "$service_file"
chmod +x "$service_file"
batocera-services enable native-x11-desktop >/dev/null 2>&1
batocera-services start native-x11-desktop >/dev/null 2>&1 || bash "$service_file" start

# Ports entry, with a controller mapping (left stick is the mouse, A/B click,
# X opens the app menu, Hotkey+Start closes the desktop)
echo "Creating Ports entry..."
mkdir -p "$ports_dir/images"
cat > "$port_script" <<'PORT'
#!/bin/bash
# Native X11 Desktop (BUA). F1 in EmulationStation opens it too.
# Press EmulationStation in the taskbar, or Hotkey+Start, to return.
exec /userdata/system/add-ons/native-x11-desktop/native-x11-desktop-launch.sh
PORT
chmod +x "$port_script"
wget -q --show-progress -O "$port_script.keys" "$base_url/extra/native-x11-desktop.keys" || fail "Failed to download the controller mapping."

# Logo in the Ports list
cp -f "$install_dir/native-x11-desktop-logo.png" "$ports_dir/images/native-x11-desktop-logo.png"
gamelist="$ports_dir/gamelist.xml"
[ -s "$gamelist" ] || printf '<?xml version="1.0"?>\n<gameList>\n</gameList>\n' > "$gamelist"
xmlstarlet ed -L -d "/gameList/game[path='./Native X11 Desktop.sh']" "$gamelist"
xmlstarlet ed -L \
    -s /gameList -t elem -n gameTMP \
    -s //gameTMP -t elem -n path -v "./Native X11 Desktop.sh" \
    -s //gameTMP -t elem -n name -v "Native X11 Desktop" \
    -s //gameTMP -t elem -n desc -v "A native X11 desktop with a taskbar, app menu and file manager. F1 in EmulationStation opens it too. Press EmulationStation in the taskbar, or Hotkey+Start, to return." \
    -s //gameTMP -t elem -n image -v "./images/native-x11-desktop-logo.png" \
    -r //gameTMP -v game \
    "$gamelist"

curl -s http://127.0.0.1:1234/reloadgames >/dev/null

echo ""
echo "$APPNAME is installed."
echo "Press F1 in EmulationStation, or open Ports > Native X11 Desktop."
echo "Press EmulationStation in the taskbar to return."
