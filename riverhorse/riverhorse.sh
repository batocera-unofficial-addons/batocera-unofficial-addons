#!/bin/bash
# Installer for Riverhorse, a PlayStation emulator offered as an alternative to
# DuckStation in the psx system's emulator list.
#
# Riverhorse is based on the DuckStation that Batocera ships and reads the same
# settings, so it builds on Batocera's own DuckStation: a batocera-launch
# emulator on Batocera 44 and later (launch/), a configgen generator on 43 and
# earlier (generator/). The psx emulator list and the ES options are copied from
# this Batocera's own DuckStation entries, so they always match the installed
# version.

APPNAME="Riverhorse"
install_dir="/userdata/system/add-ons/riverhorse"
es_config_dir="/userdata/system/configs/emulationstation"
es_systems="$es_config_dir/es_systems_psx.cfg"
es_features="$es_config_dir/es_features_riverhorse.cfg"
# Marks an es_systems_psx.cfg this add-on created (the uninstaller removes it)
created_mark="$install_dir/es_systems_psx.created"
# Python's per-user site-packages, as seen by EmulationStation (HOME=/userdata/system)
user_site=$(HOME=/userdata/system python3 -c 'import site; print(site.getusersitepackages())')
base_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/riverhorse"
bua_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app"

fail() {
    dialog --title "$APPNAME" --msgbox "$1" 10 60
    exit 1
}

# Pick the launcher by Batocera version: 44 and later use batocera-launch,
# 43 and earlier use configgen's emulatorlauncher. Either way Riverhorse builds
# on Batocera's own DuckStation, so check that it is there. -I keeps the
# per-user folders and the current directory out, so only the system's own
# packages count.
batocera_version=$(batocera-version 2>/dev/null)
major=$(echo "$batocera_version" | grep -o '^[0-9]*')
echo "Batocera version: ${batocera_version:-unknown}"
[ -n "$major" ] || fail "Could not read the Batocera version."
if [ "$major" -ge 44 ]; then
    launcher="batocera-launch"
    package="batocera_launch.emulators.duckstation"
else
    launcher="emulatorlauncher"
    package="configgen.generators.duckstation.duckstationGenerator"
fi
python3 -I -c "import $package" 2>/dev/null \
    || fail "Batocera $major should have $launcher with DuckStation, but $package is missing. $APPNAME was not installed."
echo "Launcher: $launcher"
# Batocera's launcher code is the same on every board, but DuckStation itself is
# only built for boards with GLES3 (not RK3326 or S9Gen4); others have at most
# DuckStation Legacy. Riverhorse is set up through the current DuckStation's
# settings and files, so it needs that one.
if [ ! -x /usr/bin/duckstation-qt ] && [ ! -x /usr/bin/duckstation-nogui ]; then
    fail "$APPNAME needs Batocera's DuckStation, which this device's Batocera does not include (it needs OpenGL ES 3 / Vulkan graphics)."
fi

case "$(uname -m)" in
    x86_64)  asset="Riverhorse-x64.AppImage" ;;
    aarch64) asset="Riverhorse-arm64.AppImage" ;;
    *)       fail "$APPNAME runs on x86_64 and arm64 (aarch64). This machine is $(uname -m)." ;;
esac

system_es_systems=/usr/share/emulationstation/es_systems.cfg
system_es_features=/usr/share/emulationstation/es_features.cfg
xmlstarlet sel -t -c "/systemList/system[name='psx']/emulators" "$system_es_systems" >/dev/null 2>&1 \
    || fail "This Batocera has no psx system in $system_es_systems."
xmlstarlet sel -t -c "/features/emulator[@name='duckstation']" "$system_es_features" >/dev/null 2>&1 \
    || fail "This Batocera has no DuckStation options in $system_es_features."

echo "Installing $APPNAME..."
mkdir -p "$install_dir" "$es_config_dir"

# Latest release
echo "Finding the latest $APPNAME release..."
url=$(curl -fsSL https://api.github.com/repos/thenotoriousfox/riverhorse/releases/latest \
    | grep '"browser_download_url"' | grep "/$asset\"" | head -1 | cut -d '"' -f 4)
[ -n "$url" ] || fail "Could not find $asset in the latest $APPNAME release."

echo "Downloading $APPNAME..."
wget -q --show-progress -O "$install_dir/Riverhorse.AppImage.tmp" "$url" || fail "Failed to download $APPNAME."
mv -f "$install_dir/Riverhorse.AppImage.tmp" "$install_dir/Riverhorse.AppImage"
chmod +x "$install_dir/Riverhorse.AppImage"

if [ "$launcher" = "batocera-launch" ]; then
    # A package plus the dist-info that registers it as the "riverhorse" emulator
    echo "Installing the batocera-launch emulator..."
    plugin_dir="$user_site/batocera_launch_riverhorse"
    dist_info="$user_site/batocera_launch_riverhorse-1.0.dist-info"
    mkdir -p "$plugin_dir" "$dist_info"
    wget -q --show-progress -O "$plugin_dir/__init__.py.tmp" "$base_url/launch/batocera_launch_riverhorse/__init__.py" \
        || fail "Failed to download the batocera-launch emulator."
    mv -f "$plugin_dir/__init__.py.tmp" "$plugin_dir/__init__.py"
    printf 'Metadata-Version: 2.1\nName: batocera-launch-riverhorse\nVersion: 1.0\n' > "$dist_info/METADATA"
    printf '[batocera_launch.emulators]\nriverhorse = batocera_launch_riverhorse:Riverhorse\n' > "$dist_info/entry_points.txt"
else
    # BUA's Python hook adds add-ons/*/generator to configgen's generators
    if [ ! -f "$user_site/usercustomize.py" ]; then
        echo "Installing BUA Python hook..."
        mkdir -p "$user_site"
        wget -q --show-progress -O "$user_site/usercustomize.py" "$bua_url/usercustomize.py" \
            || fail "Failed to download the BUA Python hook."
    fi
    echo "Installing the configgen generator..."
    gen_dir="$install_dir/generator/riverhorse"
    mkdir -p "$gen_dir"
    for f in __init__.py riverhorseGenerator.py; do
        wget -q --show-progress -O "$gen_dir/$f.tmp" "$base_url/generator/riverhorse/$f" \
            || fail "Failed to download the configgen generator."
        mv -f "$gen_dir/$f.tmp" "$gen_dir/$f"
    done
fi

# psx emulator list: Batocera's own, plus Riverhorse. If another add-on (or the
# user) already has an es_systems_psx.cfg, Riverhorse is added to that one.
echo "Adding $APPNAME to the PlayStation emulators..."
if [ ! -f "$es_systems" ]; then
    {
        printf '<?xml version="1.0" encoding="UTF-8" ?>\n<systemList>\n  <system>\n    <name>psx</name>\n'
        xmlstarlet sel -t -c "/systemList/system[name='psx']/emulators" "$system_es_systems"
        printf '\n  </system>\n</systemList>\n'
    } > "$es_systems"
    touch "$created_mark"
fi
xmlstarlet ed -L -d "/systemList/system[name='psx']/emulators/emulator[@name='riverhorse']" "$es_systems"
xmlstarlet ed -L \
    -s "/systemList/system[name='psx']/emulators" -t elem -n emulatorTMP \
    -s "//emulatorTMP" -t attr -n name -v riverhorse \
    -s "//emulatorTMP" -t elem -n cores \
    -s "//emulatorTMP/cores" -t elem -n core -v riverhorse \
    -s "//emulatorTMP/cores/core" -t attr -n default -v false \
    -r "//emulatorTMP" -v emulator \
    "$es_systems" || fail "Failed to add $APPNAME to $es_systems."

# ES options (graphics, BIOS patch, rewind...): DuckStation's own, since the
# emulator reads the same settings
echo "Adding the ES options..."
{
    printf '<?xml version="1.0" encoding="UTF-8" ?>\n<features>\n'
    xmlstarlet sel -t -c "/features/emulator[@name='duckstation']" "$system_es_features" \
        | sed '1s/<emulator name="duckstation"/<emulator name="riverhorse"/'
    printf '\n</features>\n'
} > "$es_features"

# Icon, from the AppImage
echo "Extracting icon..."
icon_tmp=$(mktemp -d)
( cd "$icon_tmp" && "$install_dir/Riverhorse.AppImage" --appimage-extract io.github.thenotoriousfox.Riverhorse.png >/dev/null 2>&1 )
if [ -f "$icon_tmp/squashfs-root/io.github.thenotoriousfox.Riverhorse.png" ]; then
    mkdir -p "$install_dir/extra"
    cp -f "$icon_tmp/squashfs-root/io.github.thenotoriousfox.Riverhorse.png" "$install_dir/extra/icon.png"
fi
rm -rf "$icon_tmp"

# Desktop entry (F1 > Applications), kept on /userdata and put back at boot
echo "Creating desktop entry..."
desktop_file="/usr/share/applications/Riverhorse.desktop"
persistent_desktop="/userdata/system/configs/riverhorse/Riverhorse.desktop"
mkdir -p /userdata/system/configs/riverhorse
cat <<DESKTOP > "$persistent_desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Riverhorse
Exec=env XDG_CONFIG_HOME=/userdata/system/configs $install_dir/Riverhorse.AppImage
Icon=$install_dir/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
DESKTOP
chmod +x "$persistent_desktop"
cp -f "$persistent_desktop" "$desktop_file"
chmod +x "$desktop_file"

restore_script="/userdata/system/configs/riverhorse/restore_desktop_entry.sh"
cat <<RESTORE > "$restore_script"
#!/bin/bash
if [ ! -f "$desktop_file" ]; then
    cp "$persistent_desktop" "$desktop_file"
    chmod +x "$desktop_file"
fi
RESTORE
chmod +x "$restore_script"
touch /userdata/system/custom.sh
if ! grep -q "$restore_script" /userdata/system/custom.sh; then
    echo "bash \"$restore_script\" &" >> /userdata/system/custom.sh
fi
chmod +x /userdata/system/custom.sh

echo ""
echo "$APPNAME is installed."
echo "Choose it for PlayStation games in EmulationStation: the system's or a"
echo "game's Advanced Settings > Emulator > Riverhorse."

# EmulationStation reads es_systems/es_features only at start
killall -9 emulationstation
