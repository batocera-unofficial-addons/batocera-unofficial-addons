#!/bin/bash

# Directory paths
emulationstation_config_dir="/userdata/system/configs/emulationstation"
ps4_scripts_dir="/userdata/roms/ps4"

# URLs for files to download
es_features_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/shadps4plus/es_ps4/es_features_ps4.cfg"
es_systems_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/shadps4plus/es_ps4/es_systems_ps4.cfg"

# Create directories if they don't exist
mkdir -p "$emulationstation_config_dir"
mkdir -p "$ps4_scripts_dir"

# Download and save the .cfg files
wget -q --show-progress -O "$emulationstation_config_dir/es_features_ps4.cfg" "$es_features_url"
if [ $? -eq 0 ]; then
    echo "Downloaded es_features_ps4.cfg to $emulationstation_config_dir"
else
    echo "Failed to download es_features_ps4.cfg"
    exit 1
fi

wget -q --show-progress -O "$emulationstation_config_dir/es_systems_ps4.cfg" "$es_systems_url"
if [ $? -eq 0 ]; then
    echo "Downloaded es_systems_ps4.cfg to $emulationstation_config_dir"
else
    echo "Failed to download es_systems_ps4.cfg"
    exit 1
fi

# Batocera 44 replaced emulatorlauncher with batocera-launch. Batocera 44 also
# has its own ps4 system, which this file replaces, so with emulatorlauncher
# no ps4 game would launch at all.
batocera_major=$(batocera-version 2>/dev/null | grep -o '^[0-9]*')
echo "Batocera version: $(batocera-version 2>/dev/null || echo unknown)"
if [ -n "$batocera_major" ] && [ "$batocera_major" -ge 44 ]; then
    sed -i 's|<command>emulatorlauncher |<command>batocera-launch |' "$emulationstation_config_dir/es_systems_ps4.cfg"
fi

echo "All files downloaded and configured successfully."
