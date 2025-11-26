#!/bin/bash

# Variables
install_dir="/userdata/system/add-ons/shadps4"

# URLs
shadps4_release_url=$(curl -s https://api.github.com/repos/AzaharPlus/shadPS4Plus/releases/latest | grep "browser_download_url" | grep "linux.*\.zip" | cut -d '"' -f 4)

# Prepare the installation directory
echo "Setting up installation directory at $install_dir..."
rm -rf "$install_dir"
mkdir -p "$install_dir"
mkdir -p /userdata/system/.local/share/shadPS4

# Download ShadPS4 v0.7.0 QT build
echo "Downloading ShadPS4 Plus build..."
wget -q --show-progress -O "$install_dir/shadps4.zip" "$shadps4_release_url"

# Unzip files
echo "Unzipping downloaded files..."
unzip -q "$install_dir/shadps4.zip" -d "$install_dir"

# Cleanup zip files
echo "Cleaning up zip files..."
rm -f "$install_dir"/*.zip

# Set executable permissions
chmod a+x "$install_dir/shadps4plus.AppImage"

# Download supporting scripts
monitor_script_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/shadps4plus/monitor_shadps4.sh"
launchers_script_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/shadps4plus/create_game_launchers.sh"

wget -q --show-progress -O "$install_dir/monitor_shadps4.sh" "$monitor_script_url"
wget -q --show-progress -O "$install_dir/create_game_launchers.sh" "$launchers_script_url"
chmod +x "$install_dir/monitor_shadps4.sh" "$install_dir/create_game_launchers.sh"

# Create launcher script
cat <<EOF > "$install_dir/launch_shadps4.sh"
#!/bin/bash
# Start monitor script
"$install_dir/monitor_shadps4.sh" &
# Launch the ShadPS4 QT AppImage
DISPLAY=:0.0 "$install_dir/shadps4plus.AppImage" "\$@"
EOF
chmod +x "$install_dir/launch_shadps4.sh"

# Setup desktop entry
icon_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/shadps4plus/extra/shadps4-icon.png"
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
curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/shadps4plus/es_ps4/es_ps4_install.sh | bash

# Finish
killall -9 emulationstation
