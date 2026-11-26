#!/bin/bash
# Installer for the Native Wayland Desktop. Called by native-desktop.sh
# (the unified BUA entry) when Wayland (labwc) is detected, or directly.
#
# It runs a second copy of labwc, Batocera's own compositor, full screen,
# with a taskbar, an app menu (F1 > Applications and BUA add-ons), icons on
# the wallpaper (/userdata/system/Desktop), dark mode, and windows that can
# be moved, minimized and maximized. It opens with F1 in EmulationStation like
# the old desktop, and from Ports > Native Wayland Desktop. Everything it uses is
# already part of Batocera (labwc, GTK, PCManFM, xterm), so the add-on itself
# is under 1 MB and nothing else is downloaded.
#
# F1 opens whichever desktop was installed last: installing this one takes F1
# over from KDE Plasma Desktop, and installing Plasma again gives it back.

APPNAME="Native Wayland Desktop"
install_dir="/userdata/system/add-ons/native-wayland-desktop"
ports_dir="/userdata/roms/ports"
port_script="$ports_dir/Native Wayland Desktop.sh"
service_file="/userdata/system/services/native-wayland-desktop"
base_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/native-wayland-desktop"

fail() {
    dialog --title "$APPNAME" --msgbox "$1" 10 60
    exit 1
}

# Requires Wayland (labwc)
pgrep -x labwc >/dev/null || fail "$APPNAME needs Batocera's Wayland desktop (labwc), not X11 (Openbox)."

echo "Installing $APPNAME..."
mkdir -p "$install_dir/config"

echo "Downloading $APPNAME..."
for f in native-wayland-desktop-launch.sh native-wayland-desktop-session.sh native-wayland-desktop-exit.sh \
         native-wayland-desktop-panel.py native-wayland-desktop-desktop.py native-wayland-desktop-service native-wayland-desktop-logo.png wallpaper.png; do
    wget -q --show-progress -O "$install_dir/$f.tmp" "$base_url/extra/$f" || fail "Failed to download $f."
    mv -f "$install_dir/$f.tmp" "$install_dir/$f"
done
for f in rc.xml menu.xml themerc-override autostart; do
    wget -q --show-progress -O "$install_dir/config/$f.tmp" "$base_url/extra/config/$f" || fail "Failed to download config/$f."
    mv -f "$install_dir/config/$f.tmp" "$install_dir/config/$f"
done
rm -f "$install_dir/native-wayland-desktop-wallpaper.sh"  # older versions drew the wallpaper with swaybg
chmod +x "$install_dir"/*.sh "$install_dir"/*.py "$install_dir/native-wayland-desktop-service" "$install_dir/config/autostart"

# F1 opens the Native Wayland Desktop: a Batocera service, enabled at boot. The last
# desktop installed gets F1, so KDE Plasma Desktop's service is stopped and
# switched off (Plasma itself stays installed and opens from Ports).
echo "Setting up F1..."
if [ -f /userdata/system/services/kdeplasma ]; then
    bash /userdata/system/services/kdeplasma stop >/dev/null 2>&1
    batocera-services disable kdeplasma >/dev/null 2>&1
    echo "F1 now opens the Native Wayland Desktop instead of KDE Plasma (Plasma is still in Ports)."
fi
mkdir -p /userdata/system/services
cp -f "$install_dir/native-wayland-desktop-service" "$service_file"
chmod +x "$service_file"
batocera-services enable native-wayland-desktop >/dev/null 2>&1
batocera-services start native-wayland-desktop >/dev/null 2>&1 || bash "$service_file" start

# Ports entry, with a controller mapping (left stick is the mouse, A/B click,
# X opens the app menu, Hotkey+Start closes the desktop)
echo "Creating Ports entry..."
mkdir -p "$ports_dir/images"
cat > "$port_script" <<'PORT'
#!/bin/bash
# Native Wayland Desktop (BUA). F1 in EmulationStation opens it too.
# Press EmulationStation in the taskbar, or Hotkey+Start, to return.
exec /userdata/system/add-ons/native-wayland-desktop/native-wayland-desktop-launch.sh
PORT
chmod +x "$port_script"
wget -q --show-progress -O "$port_script.keys" "$base_url/extra/native-wayland-desktop.keys" || fail "Failed to download the controller mapping."

# Logo in the Ports list
cp -f "$install_dir/native-wayland-desktop-logo.png" "$ports_dir/images/native-wayland-desktop-logo.png"
gamelist="$ports_dir/gamelist.xml"
[ -s "$gamelist" ] || printf '<?xml version="1.0"?>\n<gameList>\n</gameList>\n' > "$gamelist"
xmlstarlet ed -L -d "/gameList/game[path='./Native Wayland Desktop.sh']" "$gamelist"
xmlstarlet ed -L \
    -s /gameList -t elem -n gameTMP \
    -s //gameTMP -t elem -n path -v "./Native Wayland Desktop.sh" \
    -s //gameTMP -t elem -n name -v "Native Wayland Desktop" \
    -s //gameTMP -t elem -n desc -v "A native Wayland desktop with a taskbar, app menu and file manager. F1 in EmulationStation opens it too. Press EmulationStation in the taskbar, or Hotkey+Start, to return." \
    -s //gameTMP -t elem -n image -v "./images/native-wayland-desktop-logo.png" \
    -r //gameTMP -v game \
    "$gamelist"

curl -s http://127.0.0.1:1234/reloadgames >/dev/null

echo ""
echo "$APPNAME is installed."
echo "Press F1 in EmulationStation, or open Ports > Native Wayland Desktop."
echo "Press EmulationStation in the taskbar to return."
