#!/bin/bash

# Step 1: Check if /userdata/system/add-ons/shadps4 exists
if [ -d "/userdata/system/add-ons/shadps4" ]; then

    # Step 2: Check if Shadps4-sdl.AppImage exists
    if [ ! -f "/userdata/system/add-ons/Shadps4-sdl.AppImage" ]; then
        # Step 3: Show dialog message
        dialog --title "ShadPS4 Updated" --msgbox "ShadPS4 has been updated.\n\nFor maximum compatibility, please delete your current launchers and reopen ShadPS4." 10 50
    else
        # Step 4: Check the first .sh file in /userdata/roms/ps4
        first_sh_file=$(find /userdata/roms/ps4 -maxdepth 1 -type f -name "*.sh" | head -n 1)
        if [ -f "$first_sh_file" ]; then
            if grep -q "Shadps4-qt.AppImage" "$first_sh_file"; then
                # Step 3: Show dialog again if old launcher is detected
                dialog --title "ShadPS4 Updated" --msgbox "ShadPS4 has been updated.\n\nFor maximum compatibility, please delete your current launchers and reopen ShadPS4." 10 50
            fi
        fi
    fi
fi

# Variables
shadps4_version="0.7.0"
install_dir="/userdata/system/add-ons/shadps4"

# URLs
shadps4_release_url="https://github.com/shadps4-emu/shadPS4/releases/download/v.${shadps4_version}/shadps4-linux-qt-${shadps4_version}.zip"
sdl_latest_url=$(curl -s https://api.github.com/repos/shadps4-emu/shadPS4/releases/latest | grep "browser_download_url" | grep "shadps4-linux-sdl.*\.zip" | cut -d '"' -f 4)

# Check URLs
if [ -z "$shadps4_release_url" ] || [ -z "$sdl_latest_url" ]; then
    echo "Failed to retrieve one or more release URLs."
    exit 1
fi

# Prepare the installation directory
echo "Setting up installation directory at $install_dir..."
rm -rf "$install_dir"
mkdir -p "$install_dir"
mkdir -p /userdata/system/.local/share/shadPS4

# Download ShadPS4 v0.7.0 QT build
echo "Downloading ShadPS4 v${shadps4_version} QT build..."
wget -q --show-progress -O "$install_dir/shadps4-qt.zip" "$shadps4_release_url"

# Download ShadPS4 latest SDL build
echo "Downloading ShadPS4 latest SDL build..."
wget -q --show-progress -O "$install_dir/shadps4-sdl.zip" "$sdl_latest_url"

# Unzip files
echo "Unzipping downloaded files..."
unzip -q "$install_dir/shadps4-qt.zip" -d "$install_dir"
unzip -q "$install_dir/shadps4-sdl.zip" -d "$install_dir"

# Cleanup zip files
echo "Cleaning up zip files..."
rm -f "$install_dir"/*.zip

# Set executable permissions
chmod a+x "$install_dir/Shadps4-qt.AppImage"
chmod a+x "$install_dir/Shadps4-sdl.AppImage"

# Download supporting scripts
monitor_script_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/shadps4/monitor_shadps4.sh"
launchers_script_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/shadps4/create_game_launchers.sh"

wget -q --show-progress -O "$install_dir/monitor_shadps4.sh" "$monitor_script_url"
wget -q --show-progress -O "$install_dir/create_game_launchers.sh" "$launchers_script_url"
chmod +x "$install_dir/monitor_shadps4.sh" "$install_dir/create_game_launchers.sh"

# Create launcher script
cat <<EOF > "$install_dir/launch_shadps4.sh"
#!/bin/bash
# Start monitor script
"$install_dir/monitor_shadps4.sh" &
# Launch the ShadPS4 QT AppImage
DISPLAY=:0.0 "$install_dir/Shadps4-qt.AppImage" "\$@"
EOF
chmod +x "$install_dir/launch_shadps4.sh"

# Setup desktop entry
icon_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/shadps4/extra/shadps4-icon.png"
mkdir -p "$install_dir/extra"
wget -q --show-progress -O "$install_dir/extra/shadps4-icon.png" "$icon_url"

cat <<EOF > "$install_dir/shadps4.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=ShadPS4 Emulator
Exec=$install_dir/launch_shadps4.sh
Icon=$install_dir/extra/shadps4-icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$install_dir/shadps4.desktop"
cp "$install_dir/shadps4.desktop" /usr/share/applications/shadps4.desktop

# Restore desktop entry script
cat <<EOF > "$install_dir/restore_desktop_entry.sh"
#!/bin/bash
desktop_file="/usr/share/applications/shadps4.desktop"
if [ ! -f "\$desktop_file" ]; then
    cp "$install_dir/shadps4.desktop" "\$desktop_file"
    chmod +x "\$desktop_file"
fi
EOF
chmod +x "$install_dir/restore_desktop_entry.sh"

# Add to startup script
custom_startup="/userdata/system/custom.sh"
if ! grep -q "$install_dir/restore_desktop_entry.sh" "$custom_startup"; then
    echo "bash $install_dir/restore_desktop_entry.sh &" >> "$custom_startup"
fi
chmod +x "$custom_startup"

# Run ES System Script
curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/shadps4/es_ps4/es_ps4_install.sh | bash

# Finish
echo "Installation complete! ShadPS4 v${shadps4_version} (QT) and latest SDL build installed successfully."
killall -9 emulationstation
