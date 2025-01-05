#!/bin/bash

# Step 1: Fetch the latest release of ShadPS4
echo "Fetching the latest ShadPS4 release..."
latest_release_url=$(curl -s https://api.github.com/repos/shadps4-emu/shadPS4/releases/latest | grep "browser_download_url" | grep "shadps4-linux-qt-.*\.zip" | cut -d '"' -f 4)

if [ -z "$latest_release_url" ]; then
    echo "Failed to retrieve the latest ShadPS4 release URL."
    exit 1
fi

# Step 2: Prepare the installation directory
install_dir="/userdata/system/add-ons/shadps4"
echo "Preparing installation directory at $install_dir..."

if [ -d "$install_dir" ]; then
    echo "ShadPS4 exists. Updating it..."
    rm -rf "$install_dir"
fi

mkdir -p "$install_dir"

# Step 3: Download the zip file
echo "Downloading ShadPS4 zip from $latest_release_url..."
wget -q --show-progress -O "$install_dir/shadps4.zip" "$latest_release_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the ShadPS4 zip file."
    exit 1
fi

# Step 4: Unzip the downloaded file
echo "Unzipping ShadPS4..."
unzip -q "$install_dir/shadps4.zip" -d "$install_dir"

if [ $? -ne 0 ]; then
    echo "Failed to unzip the ShadPS4 file."
    exit 1
fi

# Step 5: Delete the zip file
echo "Cleaning up... Deleting the zip file."
rm -f "$install_dir/shadps4.zip"

# Step 6: Set executable permissions for the AppImage
chmod a+x "$install_dir/Shadps4-qt.AppImage"
echo "ShadPS4 AppImage marked as executable."


# Step 8: Download and set up monitor_shadps4 and create_game_launchers
echo "Downloading supporting scripts..."
monitor_script_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/shadps4/monitor_shadps4.sh"
launchers_script_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/shadps4/create_game_launchers.sh"

monitor_script="$install_dir/monitor_shadps4.sh"
launchers_script="$install_dir/create_game_launchers.sh"

wget -q --show-progress -O "$monitor_script" "$monitor_script_url"
wget -q --show-progress -O "$launchers_script" "$launchers_script_url"

chmod +x "$monitor_script"
chmod +x "$launchers_script"

# Step 9: Create a persistent desktop entry
echo "Creating persistent desktop entry for ShadPS4..."
persistent_desktop="$install_dir/shadps4.desktop"
launcher_script="$install_dir/launch_shadps4.sh"

# Create the launcher script
cat <<EOF > "$launcher_script"
#!/bin/bash
# Start monitor script
"$monitor_script" &
# Launch the ShadPS4 AppImage
DISPLAY=:0.0 "$install_dir/Shadps4-qt.AppImage" "\$@"
EOF
chmod +x "$launcher_script"

# Step 9.1: Download and set up the icon
echo "Downloading ShadPS4 icon..."
icon_dir="$install_dir/extra"
mkdir -p "$icon_dir"
icon_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/shadps4/extra/shadps4-icon.png"
icon_path="$icon_dir/shadps4-icon.png"

wget -q --show-progress -O "$icon_path" "$icon_url"

# Create the desktop entry
cat <<EOF > "$persistent_desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=ShadPS4 Emulator
Exec=$launcher_script
Icon=$icon_path
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$persistent_desktop"

cp "$persistent_desktop" /usr/share/applications/shadps4.desktop
chmod +x /usr/share/applications/shadps4.desktop

# Ensure desktop entry is restored at startup
restore_script="$install_dir/restore_desktop_entry.sh"
cat <<EOF > "$restore_script"
#!/bin/bash
# Restore ShadPS4 desktop entry
desktop_file="/usr/share/applications/shadps4.desktop"
if [ ! -f "\$desktop_file" ]; then
    echo "Restoring ShadPS4 desktop entry..."
    cp "$persistent_desktop" "\$desktop_file"
    chmod +x "\$desktop_file"
fi
EOF
chmod +x "$restore_script"

# Add to startup script
custom_startup="/userdata/system/custom.sh"
if ! grep -q "$restore_script" "$custom_startup"; then
    echo "Adding ShadPS4 restore script to startup..."
    echo "bash $restore_script &" >> "$custom_startup"
fi
chmod +x "$custom_startup"

# Step 10: Run ES System Script
echo "Creating ES System for PS4..."
curl -L https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/shadps4/es_ps4/es_ps4_install.sh | bash

echo
echo "Installation complete! A desktop entry has been created and will persist across reboots."
killall -9 emulationstation
echo "Script execution completed."
