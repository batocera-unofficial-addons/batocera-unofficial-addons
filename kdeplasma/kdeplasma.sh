#!/bin/bash
# Installer for KDE Plasma Desktop: the full KDE Plasma 6 desktop on
# Batocera 44 and later (Wayland/labwc), opened with F1 in EmulationStation
# like the old desktop, and from Ports > KDE Plasma.
#
# Plasma comes from an Arch Linux system kept in its own folder
# (/userdata/system/add-ons/kdeplasma, about 4-5 GB) and runs with chroot, so
# Batocera's own files and libraries are not changed. KDE's compositor runs
# full screen inside Batocera's labwc; logging out returns to
# EmulationStation. Needs internet to install (about 750 MB to download), not
# to use. Running this again updates Plasma.

APPNAME="KDE Plasma"
install_dir="/userdata/system/add-ons/kdeplasma"
ports_dir="/userdata/roms/ports"
port_script="$ports_dir/KDE Plasma.sh"
service_file="/userdata/system/services/kdeplasma"
base_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/kdeplasma"
log_file="/userdata/system/logs/kdeplasma-install.log"

fail() {
    echo "$1"
    exit 1
}

# Checks: x86_64, Batocera 44 or later, running its Wayland desktop (labwc)
[ "$(uname -m)" = "x86_64" ] || fail "KDE Plasma Desktop is for x86_64 machines. This one is $(uname -m)."
major=$(batocera-version 2>/dev/null | grep -o '^[0-9]*')
[ -n "$major" ] && [ "$major" -ge 44 ] || fail "KDE Plasma Desktop needs Batocera 44 or later."
pgrep -x labwc >/dev/null || fail "KDE Plasma Desktop needs Batocera's Wayland desktop (labwc), which is not running."
free_kb=$(df -Pk /userdata | awk 'NR==2 {print $4}')
if [ ! -d "$install_dir/rootfs/usr" ] && [ "${free_kb:-0}" -lt 8000000 ]; then
    fail "KDE Plasma Desktop needs about 8 GB of free space on /userdata to install."
fi

# Not while it is running
if pgrep -f '^/usr/bin/startplasma-waylan[d]' >/dev/null; then
    fail "KDE Plasma is running. Log out of Plasma first, then install again."
fi

echo "Installing $APPNAME..."
mkdir -p "$install_dir" /userdata/system/logs

# The add-on's own scripts
echo "Downloading $APPNAME scripts..."
for f in kdeplasma-build.sh kdeplasma-launch.sh kdeplasma-enter.py kdeplasma-exit.sh kdeplasma-places.py kdeplasma-apps.py kdeplasma-service kdeplasma-logo.png; do
    wget -q --show-progress -O "$install_dir/$f" "$base_url/extra/$f" || fail "Failed to download $f."
done
chmod +x "$install_dir"/*.sh "$install_dir/kdeplasma-service"

# Build (or update) the Plasma container. This is the long part.
echo "Building the Plasma system. This takes a while, depending on your internet speed."
bash "$install_dir/kdeplasma-build.sh" 2>&1 | tee "$log_file"
[ "${PIPESTATUS[0]}" -eq 0 ] || fail "Installing Plasma failed. See $log_file"

# F1 opens Plasma: a Batocera service, enabled at boot
echo "Setting up F1..."
mkdir -p /userdata/system/services
cp -f "$install_dir/kdeplasma-service" "$service_file"
chmod +x "$service_file"
batocera-services enable kdeplasma >/dev/null 2>&1
batocera-services start kdeplasma >/dev/null 2>&1 || bash "$service_file" start

# Ports entry, with a controller mapping (left stick is the mouse, A/B click,
# Hotkey+Start logs out)
echo "Creating Ports entry..."
mkdir -p "$ports_dir/images"
cat > "$port_script" <<'EOF'
#!/bin/bash
# KDE Plasma Desktop (BUA). F1 in EmulationStation opens it too.
# Log out of Plasma, or press Hotkey+Start, to return to EmulationStation.
exec /userdata/system/add-ons/kdeplasma/kdeplasma-launch.sh
EOF
chmod +x "$port_script"
wget -q --show-progress -O "$port_script.keys" "$base_url/extra/kdeplasma.keys" || fail "Failed to download the controller mapping."

# Logo in the Ports list
cp -f "$install_dir/kdeplasma-logo.png" "$ports_dir/images/kdeplasma-logo.png"
gamelist="$ports_dir/gamelist.xml"
[ -s "$gamelist" ] || printf '<?xml version="1.0"?>\n<gameList>\n</gameList>\n' > "$gamelist"
xmlstarlet ed -L -d "/gameList/game[path='./KDE Plasma.sh']" "$gamelist"
xmlstarlet ed -L \
    -s /gameList -t elem -n gameTMP \
    -s //gameTMP -t elem -n path -v "./KDE Plasma.sh" \
    -s //gameTMP -t elem -n name -v "KDE Plasma" \
    -s //gameTMP -t elem -n desc -v "The KDE Plasma desktop. F1 in EmulationStation opens it too. Log out, or press Hotkey+Start, to return." \
    -s //gameTMP -t elem -n image -v "./images/kdeplasma-logo.png" \
    -r //gameTMP -v game \
    "$gamelist"

# Refresh the Ports menu
curl -s http://127.0.0.1:1234/reloadgames >/dev/null

echo ""
echo "$APPNAME is installed."
echo "Press F1 in EmulationStation, or open Ports > KDE Plasma."
echo "Log out of Plasma to return to EmulationStation."
