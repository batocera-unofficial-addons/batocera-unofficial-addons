#!/bin/bash

echo "========================================="
echo "Uninstalling: AzaharPlus"
echo "========================================="
echo ""

# Remove addon directory
if [ -d "/userdata/system/add-ons/azaharplus" ]; then
    echo "Removing /userdata/system/add-ons/azaharplus"
    rm -rf "/userdata/system/add-ons/azaharplus"
fi

# Batocera 44+: the batocera-launch emulator, under any Python version's folder
rm -rf /userdata/system/.local/lib/python3*/site-packages/batocera_launch_azaharplus \
       /userdata/system/.local/lib/python3*/site-packages/batocera_launch_azaharplus-*.dist-info

# Controller mapping, unless the user changed it
evmapy_keys="/userdata/system/configs/evmapy/azaharplus.keys"
if [ -f "$evmapy_keys" ] && cmp -s "$evmapy_keys" /usr/share/evmapy/3ds.azahar.keys; then
    echo "Removing controller mapping"
    rm -f "$evmapy_keys"
fi

# Remove ES config files
if [ -f "/userdata/system/configs/emulationstation/es_systems_3ds.cfg" ]; then
    echo "Removing es_systems_3ds.cfg"
    rm -f "/userdata/system/configs/emulationstation/es_systems_3ds.cfg"
fi

if [ -f "/userdata/system/configs/emulationstation/es_features_azaharplus.cfg" ]; then
    echo "Removing es_features_azaharplus.cfg"
    rm -f "/userdata/system/configs/emulationstation/es_features_azaharplus.cfg"
fi

# Remove desktop entry
if [ -f "/usr/share/applications/AzaharPlus.desktop" ]; then
    echo "Removing desktop entry"
    rm -f "/usr/share/applications/AzaharPlus.desktop"
fi

if [ -f "/userdata/system/configs/azaharplus/AzaharPlus.desktop" ]; then
    echo "Removing persistent desktop entry"
    rm -f "/userdata/system/configs/azaharplus/AzaharPlus.desktop"
fi

# Remove restore script and custom.sh entry
restore_script="/userdata/system/configs/azaharplus/restore_desktop_entry.sh"
if [ -f "$restore_script" ]; then
    sed -i "\|$restore_script|d" /userdata/system/custom.sh
    rm -f "$restore_script"
fi

rmdir /userdata/system/configs/azaharplus 2>/dev/null

echo ""
echo "========================================="
echo "Uninstallation complete: AzaharPlus"
echo "========================================="

killall -9 emulationstation
