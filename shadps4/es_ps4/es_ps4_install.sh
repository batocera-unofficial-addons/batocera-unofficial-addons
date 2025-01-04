#!/bin/bash

# Directory paths
emulationstation_config_dir="/userdata/system/configs/emulationstation"
ps4_scripts_dir="/userdata/roms/ps4"

# URLs for files to download
es_features_url="https://github.com/trashbus99/batocera-unofficial-addons/raw/main/shadps4/es_ps4/es_features_ps4.cfg"
es_systems_url="https://github.com/trashbus99/batocera-unofficial-addons/raw/main/shadps4/es_ps4/es_systems_ps4.cfg"
update_script_url="https://github.com/trashbus99/batocera-unofficial-addons/raw/main/shadps4/es_ps4/%2BUPDATE-PS4-SHORTCUTS.sh"

# Create directories if they don't exist
mkdir -p "$emulationstation_config_dir"
mkdir -p "$ps4_scripts_dir"

# Download and save the .cfg files
wget -O "$emulationstation_config_dir/es_features_ps4.cfg" "$es_features_url"
if [ $? -eq 0 ]; then
    echo "Downloaded es_features_ps4.cfg to $emulationstation_config_dir"
else
    echo "Failed to download es_features_ps4.cfg"
    exit 1
fi

wget -O "$emulationstation_config_dir/es_systems_ps4.cfg" "$es_systems_url"
if [ $? -eq 0 ]; then
    echo "Downloaded es_systems_ps4.cfg to $emulationstation_config_dir"
else
    echo "Failed to download es_systems_ps4.cfg"
    exit 1
fi

# Download and save the update script
wget -O "$ps4_scripts_dir/+UPDATE-PS4-SHORTCUTS.sh" "$update_script_url"
if [ $? -eq 0 ]; then
    echo "Downloaded +UPDATE-PS4-SHORTCUTS.sh to $ps4_scripts_dir"
else
    echo "Failed to download +UPDATE-PS4-SHORTCUTS.sh"
    exit 1
fi

# Make the update script executable
chmod +x "$ps4_scripts_dir/+UPDATE-PS4-SHORTCUTS.sh"
if [ $? -eq 0 ]; then
    echo "Made +UPDATE-PS4-SHORTCUTS.sh executable"
else
    echo "Failed to make +UPDATE-PS4-SHORTCUTS.sh executable"
    exit 1
fi

echo "All files downloaded and configured successfully."
