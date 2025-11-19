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

echo "All files downloaded and configured successfully."
