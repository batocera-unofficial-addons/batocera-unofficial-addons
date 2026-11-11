#!/bin/bash
# Installer for AzaharPlus, a 3DS emulator offered as an alternative to Azahar
# in the 3ds system's emulator list.
# Batocera 44 replaced configgen/emulatorlauncher with batocera-launch, which
# finds emulators through Python entry points, so the installer reads the
# Batocera version and installs the matching launcher.

# Variables
install_dir="/userdata/system/add-ons/azaharplus"
es_config_dir="/userdata/system/configs/emulationstation"
# Python's per-user site-packages, as seen by EmulationStation (HOME=/userdata/system)
user_site=$(HOME=/userdata/system python3 -c 'import site; print(site.getusersitepackages())')
base_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/azaharplus"
bua_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app"

fail() {
    echo "$1"
    exit 1
}

# Pick the launcher by Batocera version: 44 and later use batocera-launch,
# 43 and earlier use configgen's emulatorlauncher.
batocera_version=$(batocera-version 2>/dev/null)
major=$(echo "$batocera_version" | grep -o '^[0-9]*')
echo "Batocera version: ${batocera_version:-unknown}"
[ -n "$major" ] || fail "Could not read the Batocera version."
if [ "$major" -ge 44 ]; then
    launcher="batocera-launch"
    package="batocera_launch.emulators.azahar"
else
    launcher="emulatorlauncher"
    package="configgen.generators"
fi
# Make sure that launcher is really there (early Batocera 44 test builds still
# had configgen). -I keeps the per-user folders and the current directory out,
# so only the system's own packages count. On 44 the emulator builds on
# Batocera's own Azahar emulator, so check for that too.
python3 -I -c "import $package" 2>/dev/null \
    || fail "Batocera $major should have $launcher, but $package is missing. AzaharPlus was not installed."
echo "Launcher: $launcher"

# Ensure BUA Python hook is present (it lets emulatorlauncher find the generator)
if [ "$launcher" = "emulatorlauncher" ] && [ ! -f "$user_site/usercustomize.py" ]; then
    echo "Installing BUA Python hook..."
    mkdir -p "$user_site"
    wget -q --show-progress -O "$user_site/usercustomize.py" "$bua_url/usercustomize.py"
fi

# Prepare installation directory
echo "Setting up installation directory at $install_dir..."
rm -rf "$install_dir"
mkdir -p "$es_config_dir"

# Get latest AzaharPlus AppImage release URL
echo "Fetching latest AzaharPlus release..."
azaharplus_url=$(curl -fsSL https://api.github.com/repos/AzaharPlus/AzaharPlus/releases/latest \
    | grep '"browser_download_url"' \
    | grep -i '\.AppImage"' \
    | head -1 \
    | cut -d '"' -f 4)

if [ -z "$azaharplus_url" ]; then
    echo "Failed to find an AzaharPlus AppImage in the latest release."
    exit 1
fi

# Download AppImage directly
echo "Downloading AzaharPlus AppImage..."
if ! wget -q --show-progress -O "$install_dir/azahar.AppImage" "$azaharplus_url"; then
    echo "Failed to download AzaharPlus."
    exit 1
fi

chmod +x "$install_dir/azahar.AppImage"

# Download the launcher for this Batocera
if [ "$launcher" = "batocera-launch" ]; then
    # A package plus the dist-info that registers it as the "azaharplus" emulator
    echo "Downloading batocera-launch emulator..."
    plugin_dir="$user_site/batocera_launch_azaharplus"
    dist_info="$user_site/batocera_launch_azaharplus-1.0.dist-info"
    mkdir -p "$plugin_dir" "$dist_info"
    wget -q --show-progress -O "$plugin_dir/__init__.py" "$base_url/launch/batocera_launch_azaharplus/__init__.py" \
        || fail "Failed to download the batocera-launch emulator."
    printf 'Metadata-Version: 2.1\nName: batocera-launch-azaharplus\nVersion: 1.0\n' > "$dist_info/METADATA"
    printf '[batocera_launch.emulators]\nazaharplus = batocera_launch_azaharplus:AzaharPlus\n' > "$dist_info/entry_points.txt"
else
    echo "Downloading generator..."
    mkdir -p "$install_dir/generator/azaharplus"
    wget -q --show-progress -O "$install_dir/generator/azaharplus/__init__.py" "$base_url/generator/azaharplus/__init__.py"
    wget -q --show-progress -O "$install_dir/generator/azaharplus/azaharplusGenerator.py" "$base_url/generator/azaharplus/azaharplusGenerator.py"
fi

# Download and deploy ES config files
echo "Downloading ES configs..."
wget -q --show-progress -O "$es_config_dir/es_systems_3ds.cfg" "$base_url/extra/es_systems_3ds.cfg"
wget -q --show-progress -O "$es_config_dir/es_features_azaharplus.cfg" "$base_url/extra/es_features_azaharplus.cfg"

# Controller-to-mouse mapping (right stick moves the touch-screen pointer, R3
# clicks). evmapy looks it up by emulator name, and Batocera only ships it as
# 3ds.azahar.keys, so give AzaharPlus its own copy. Keep a user-edited one.
evmapy_keys="/userdata/system/configs/evmapy/azaharplus.keys"
if [ -f /usr/share/evmapy/3ds.azahar.keys ] && [ ! -f "$evmapy_keys" ]; then
    echo "Adding controller mapping..."
    mkdir -p "$(dirname "$evmapy_keys")"
    cp /usr/share/evmapy/3ds.azahar.keys "$evmapy_keys"
fi

# Extract icon from AppImage
echo "Extracting icon..."
mkdir -p "$install_dir/extra"
rm -rf /tmp/azahar-icon-extract
mkdir -p /tmp/azahar-icon-extract
cd /tmp/azahar-icon-extract
"$install_dir/azahar.AppImage" --appimage-extract 'usr/share/icons/hicolor/scalable/apps/org.azahar_emu.Azahar.svg' 2>/dev/null
rsvg-convert -w 128 -h 128 \
    /tmp/azahar-icon-extract/squashfs-root/usr/share/icons/hicolor/scalable/apps/org.azahar_emu.Azahar.svg \
    -o "$install_dir/extra/icon.png"
rm -rf /tmp/azahar-icon-extract
cd /

# Create persistent desktop entry
echo "Creating desktop entry..."
desktop_file="/usr/share/applications/AzaharPlus.desktop"
persistent_desktop="/userdata/system/configs/azaharplus/AzaharPlus.desktop"
mkdir -p /userdata/system/configs/azaharplus
cat <<DESKTOP > "$persistent_desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=AzaharPlus
Exec=$install_dir/azahar.AppImage
Icon=$install_dir/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
DESKTOP
chmod +x "$persistent_desktop"
cp "$persistent_desktop" "$desktop_file"
chmod +x "$desktop_file"

# Restore desktop entry on boot
restore_script="/userdata/system/configs/azaharplus/restore_desktop_entry.sh"
cat <<RESTORE > "$restore_script"
#!/bin/bash
if [ ! -f "$desktop_file" ]; then
    cp "$persistent_desktop" "$desktop_file"
    chmod +x "$desktop_file"
fi
RESTORE
chmod +x "$restore_script"
if ! grep -q "$restore_script" /userdata/system/custom.sh; then
    echo "bash \"$restore_script\" &" >> /userdata/system/custom.sh
fi
chmod +x /userdata/system/custom.sh

# Finish
echo "AzaharPlus installation complete."
killall -9 emulationstation
