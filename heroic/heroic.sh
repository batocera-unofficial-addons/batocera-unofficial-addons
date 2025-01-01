#!/bin/bash

# Set variables
INSTALL_DIR="/userdata/system/add-ons/heroic"
DESKTOP_FILE="/usr/share/applications/heroic.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/heroic/heroic.desktop"
COLLECTIONS_DIR="/userdata/system/configs/emulationstation/collections"
HEROIC_CFG="${COLLECTIONS_DIR}/Heroic.cfg"
SYSTEMS_CFG="/userdata/system/configs/emulationstation/es_systems_heroic.cfg"
LAUNCHERS_SCRIPT_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/heroic/create_game_launchers.sh"
MONITOR_SCRIPT_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/heroic/monitor_heroic.sh"
WRAPPER_SCRIPT="${INSTALL_DIR}/launch_heroic.sh"
ROM_DIR="/userdata/roms/heroic"

mkdir -p "$ROM_DIR"
mkdir -p "/userdata/system/configs/heroic"

# Fetch the latest version of Heroic from GitHub API
echo "Fetching the latest version of Heroic Games Launcher..."
HEROIC_URL=$(wget -qO- https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest | grep "browser_download_url" | grep "tar.xz" | cut -d '"' -f 4)
HEROIC_VERSION=$(basename "$HEROIC_URL" | sed -E 's/Heroic-([^-]+).*/\1/')

if [ -z "$HEROIC_URL" ]; then
    echo "Failed to fetch the latest Heroic version. Please check your internet connection or the GitHub API."
    exit 1
fi

# Download Heroic
echo "Downloading Heroic Games Launcher version $HEROIC_VERSION..."
mkdir -p "$INSTALL_DIR"
wget --show-progress -qO- "$HEROIC_URL" | tar -xJ -C "$INSTALL_DIR" --strip-components=1

# Download supporting scripts
echo "Downloading create_game_launchers.sh..."
wget --show-progress -qO "${INSTALL_DIR}/create_game_launchers.sh" "$LAUNCHERS_SCRIPT_URL"

echo "Downloading monitor_heroic.sh..."
wget --show-progress -qO "${INSTALL_DIR}/monitor_heroic.sh" "$MONITOR_SCRIPT_URL"

# Make scripts executable
chmod +x "${INSTALL_DIR}/heroic"
chmod +x "${INSTALL_DIR}/create_game_launchers.sh"
chmod +x "${INSTALL_DIR}/monitor_heroic.sh"

# Create wrapper script
echo "Creating wrapper script for Heroic..."
cat <<EOF > "$WRAPPER_SCRIPT"
#!/bin/bash
# Launch Heroic with monitoring
/userdata/system/add-ons/heroic/monitor_heroic.sh &
HOME=/userdata/system/add-ons/heroic /userdata/system/add-ons/heroic/heroic --no-sandbox
EOF

chmod +x "$WRAPPER_SCRIPT"

# Create persistent desktop entry
echo "Creating persistent desktop entry for Heroic..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Heroic Games Launcher
Exec=$WRAPPER_SCRIPT
Icon=/userdata/system/add-ons/heroic/resources/app.asar.unpacked/build/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

# Ensure the desktop entry is always restored to /usr/share/applications
echo "Ensuring Heroic desktop entry is restored at startup..."
cat <<EOF > "/userdata/system/configs/heroic/restore_desktop_entry.sh"
#!/bin/bash
# Restore Heroic desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring Heroic desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "Heroic desktop entry restored."
else
    echo "Heroic desktop entry already exists."
fi
EOF
chmod +x "/userdata/system/configs/heroic/restore_desktop_entry.sh"

# Add to startup
cat <<EOF > "/userdata/system/custom.sh"
#!/bin/bash
# Restore Heroic desktop entry at startup
bash /userdata/system/configs/heroic/restore_desktop_entry.sh &
EOF
chmod +x "/userdata/system/custom.sh"

# Create es_systems_heroic.cfg
echo "Creating Heroic Category for EmulationStation..."
cat <<EOF > "$SYSTEMS_CFG"
<?xml version="1.0"?>
<systemList>
  <system>
        <fullname>Heroic Games</fullname>
        <name>heroic</name>
        <manufacturer>PC</manufacturer>
        <release>2021</release>
        <hardware>PC</hardware>
        <path>/userdata/roms/heroic</path>
        <extension>.sh</extension>
        <command>%ROM%</command>
        <platform>pc</platform>
        <theme>heroic</theme>
  </system>
</systemList>
EOF

# Restart EmulationStation
echo "Restarting EmulationStation to apply changes..."
batocera-es-swissknife --restart &> /dev/null

# Final message
echo "Heroic Games Launcher setup complete! Installed version $HEROIC_VERSION."
echo "A desktop entry has been created and will persist across reboots."
echo "You can install games from here and launch them via the Emulation Station menu."
