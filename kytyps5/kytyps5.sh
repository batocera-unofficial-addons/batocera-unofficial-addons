#!/bin/bash
# Installer for KytyPS5, an experimental PS5 emulator.
# Installs the latest official Linux build to /userdata/system/add-ons/kytyps5
# and adds a PlayStation 5 system to EmulationStation (Hotkey+Start exits).
# Games go in /userdata/roms/ps5.
# Batocera 44 replaced configgen/emulatorlauncher with batocera-launch, which
# finds emulators through Python entry points, so the installer reads the
# Batocera version and installs the matching launcher.
# Optional: KYTY_URL=<direct .tar.gz link> to install a specific build.

# Variables
install_dir="/userdata/system/add-ons/kytyps5"
es_config_dir="/userdata/system/configs/emulationstation"
rom_dir="/userdata/roms/ps5"
batocera_conf="/userdata/system/batocera.conf"
work_dir="/userdata/system/.kytyps5-install-tmp"
# Python's per-user site-packages, as seen by EmulationStation (HOME=/userdata/system)
user_site=$(HOME=/userdata/system python3 -c 'import site; print(site.getusersitepackages())')
base_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/kytyps5"
bua_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app"
releases_api="https://api.github.com/repos/KytyPS5/KytyPS5/releases?per_page=15"

fail() {
    echo "$1"
    rm -rf "$work_dir"
    exit 1
}

# set_conf key value: add or update a line in batocera.conf
set_conf() {
    if grep -q "^$1=" "$batocera_conf" 2>/dev/null; then
        sed -i "s|^$1=.*|$1=$2|" "$batocera_conf"
    else
        [ -f "$batocera_conf" ] && [ -n "$(tail -c1 "$batocera_conf")" ] && echo >> "$batocera_conf"
        echo "$1=$2" >> "$batocera_conf"
    fi
}

if [ "$(uname -m)" != "x86_64" ]; then
    fail "KytyPS5 only has x86_64 builds. This machine is $(uname -m)."
fi

# Pick the launcher by Batocera version: 44 and later use batocera-launch,
# 43 and earlier use configgen's emulatorlauncher.
batocera_version=$(batocera-version 2>/dev/null)
major=$(echo "$batocera_version" | grep -o '^[0-9]*')
echo "Batocera version: ${batocera_version:-unknown}"
[ -n "$major" ] || fail "Could not read the Batocera version."
if [ "$major" -ge 44 ]; then
    launcher="batocera-launch"
    package="batocera_launch.emulator"
else
    launcher="emulatorlauncher"
    package="configgen.generators"
fi
# Make sure that launcher is really there (early Batocera 44 test builds still
# had configgen). -I keeps the per-user folders and the current directory out,
# so only the system's own packages count.
python3 -I -c "import $package" 2>/dev/null \
    || fail "Batocera $major should have $launcher, but $package is missing. KytyPS5 was not installed."
echo "Launcher: $launcher"

# Ensure BUA Python hook is present (it lets emulatorlauncher find the generator)
if [ "$launcher" = "emulatorlauncher" ] && [ ! -f "$user_site/usercustomize.py" ]; then
    echo "Installing BUA Python hook..."
    mkdir -p "$user_site"
    wget -q --show-progress -O "$user_site/usercustomize.py" "$bua_url/usercustomize.py"
fi

# Find the latest official Linux build, unless one was given
kyty_url="${KYTY_URL:-}"
digest=""
if [ -z "$kyty_url" ]; then
    echo "Fetching latest KytyPS5 release..."
    info=$(curl -fsSL "$releases_api" | python3 -c '
import json, sys
for rel in json.load(sys.stdin):
    for a in rel.get("assets", []):
        if a["name"].endswith("Linux-x86_64.tar.gz"):
            print(a["browser_download_url"], a.get("digest") or "")
            sys.exit(0)
')
    [ -n "$info" ] || fail "Failed to find a KytyPS5 Linux x86_64 build in the latest releases."
    kyty_url=${info%% *}
    digest=${info#* }
    [ "$digest" = "$info" ] && digest=""
fi

# Download and verify
rm -rf "$work_dir"
mkdir -p "$work_dir/extract"
echo "Downloading KytyPS5..."
wget -q --show-progress -O "$work_dir/kyty.tar.gz" "$kyty_url" || fail "Failed to download KytyPS5."

if [ -n "$digest" ]; then
    expected=${digest#sha256:}
    actual=$(sha256sum "$work_dir/kyty.tar.gz" | cut -d' ' -f1)
    [ "$expected" = "$actual" ] || fail "Checksum mismatch (expected $expected, got $actual). Not installing."
    echo "Checksum OK."
fi

# Extract. Copying over an existing install keeps anything Kyty saved there.
echo "Extracting..."
tar -xzf "$work_dir/kyty.tar.gz" -C "$work_dir/extract" || fail "Failed to extract KytyPS5."
emulator=$(find "$work_dir/extract" -name kyty_emulator -type f | head -n1)
[ -n "$emulator" ] || fail "kyty_emulator not found in the download."
mkdir -p "$install_dir"
cp -a "$(dirname "$emulator")"/. "$install_dir"/ || fail "Failed to copy KytyPS5 to $install_dir."
rm -rf "$work_dir"
chmod +x "$install_dir/kyty_emulator"
[ -f "$install_dir/launcher" ] && chmod +x "$install_dir/launcher"

# Download the launcher for this Batocera and the launch wrapper
if [ "$launcher" = "batocera-launch" ]; then
    # A package plus the dist-info that registers it as the "kyty" emulator
    echo "Downloading batocera-launch emulator..."
    plugin_dir="$user_site/batocera_launch_kyty"
    dist_info="$user_site/batocera_launch_kyty-1.0.dist-info"
    mkdir -p "$plugin_dir" "$dist_info"
    wget -q --show-progress -O "$plugin_dir/__init__.py" "$base_url/launch/batocera_launch_kyty/__init__.py" \
        || fail "Failed to download the batocera-launch emulator."
    printf 'Metadata-Version: 2.1\nName: batocera-launch-kyty\nVersion: 1.0\n' > "$dist_info/METADATA"
    printf '[batocera_launch.emulators]\nkyty = batocera_launch_kyty:Kyty\n' > "$dist_info/entry_points.txt"
else
    echo "Downloading generator..."
    mkdir -p "$install_dir/generator/kyty"
    wget -q --show-progress -O "$install_dir/generator/kyty/__init__.py" "$base_url/generator/kyty/__init__.py"
    wget -q --show-progress -O "$install_dir/generator/kyty/kytyGenerator.py" "$base_url/generator/kyty/kytyGenerator.py"
fi
wget -q --show-progress -O "$install_dir/kyty.sh" "$base_url/extra/kyty.sh"
chmod +x "$install_dir/kyty.sh"

# Download and deploy ES system
echo "Downloading ES config..."
mkdir -p "$es_config_dir"
# The ROM folder may be a link to another drive, which can be unplugged
[ -L "$rom_dir" ] || mkdir -p "$rom_dir"
wget -q --show-progress -O "$es_config_dir/es_systems_ps5.cfg" "$base_url/extra/es_systems_ps5.cfg"
if [ "$launcher" = "batocera-launch" ]; then
    sed -i 's|<command>emulatorlauncher |<command>batocera-launch |' "$es_config_dir/es_systems_ps5.cfg"
fi

# Batocera has no default emulator for ps5, so set it (without this:
# "emulator missing"). Bezels have no per-system menu for PS5, so turn them off.
set_conf ps5.emulator kyty
set_conf ps5.core kyty
set_conf ps5.bezel none

# Finish
echo "KytyPS5 installation complete. Put your PS5 games in $rom_dir."
echo "If a game exits right away, check /userdata/system/logs/kyty.log"
killall -9 emulationstation
