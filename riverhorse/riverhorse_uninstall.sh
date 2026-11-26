#!/bin/bash
# Uninstaller for Riverhorse, installed by riverhorse.sh. Your Riverhorse
# settings, memory cards and save states are kept
# (/userdata/system/configs/riverhorse, /userdata/saves/psx).

echo "========================================="
echo "Uninstalling: Riverhorse"
echo "========================================="
echo ""

install_dir="/userdata/system/add-ons/riverhorse"
es_config_dir="/userdata/system/configs/emulationstation"
es_systems="$es_config_dir/es_systems_psx.cfg"

# psx emulator list: remove the file if this add-on created it, otherwise only
# Riverhorse's entry
if [ -f "$install_dir/es_systems_psx.created" ]; then
    echo "Removing es_systems_psx.cfg"
    rm -f "$es_systems"
elif [ -f "$es_systems" ]; then
    echo "Removing Riverhorse from es_systems_psx.cfg"
    xmlstarlet ed -L -d "/systemList/system[name='psx']/emulators/emulator[@name='riverhorse']" "$es_systems"
fi
rm -f "$es_config_dir/es_features_riverhorse.cfg"

# batocera-launch emulator, under any Python version's folder
rm -rf /userdata/system/.local/lib/python3*/site-packages/batocera_launch_riverhorse \
       /userdata/system/.local/lib/python3*/site-packages/batocera_launch_riverhorse-*.dist-info

# Desktop entry and its boot-time restore
rm -f /usr/share/applications/Riverhorse.desktop /userdata/system/configs/riverhorse/Riverhorse.desktop
restore_script="/userdata/system/configs/riverhorse/restore_desktop_entry.sh"
if [ -f "$restore_script" ]; then
    [ -f /userdata/system/custom.sh ] && sed -i "\|$restore_script|d" /userdata/system/custom.sh
    rm -f "$restore_script"
fi

if [ -d "$install_dir" ]; then
    echo "Removing $install_dir"
    rm -rf "${install_dir:?}"
fi

echo ""
echo "========================================="
echo "Uninstallation complete: Riverhorse"
echo "Your settings in /userdata/system/configs/riverhorse are kept."
echo "========================================="

killall -9 emulationstation
