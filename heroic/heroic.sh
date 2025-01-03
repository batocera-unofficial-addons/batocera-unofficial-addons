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
HEROIC_URL=$(wget -qO- https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest | grep "browser_download_url" | grep ".AppImage" | cut -d '"' -f 4)
HEROIC_VERSION=$(basename "$HEROIC_URL" | sed -E 's/Heroic-([^-]+).*/\1/')

if [ -z "$HEROIC_URL" ]; then
    echo "Failed to fetch the latest Heroic version. Please check your internet connection or the GitHub API."
    exit 1
fi

# Download Heroic
echo "Downloading Heroic Games Launcher version $HEROIC_VERSION..."
mkdir -p "$INSTALL_DIR"
wget --show-progress -qO- "$HEROIC_URL" -C "$INSTALL_DIR"

# Download supporting scripts
echo "Downloading create_game_launchers.sh..."
wget --show-progress -qO "${INSTALL_DIR}/create_game_launchers.sh" "$LAUNCHERS_SCRIPT_URL"

echo "Downloading monitor_heroic.sh..."
wget --show-progress -qO "${INSTALL_DIR}/monitor_heroic.sh" "$MONITOR_SCRIPT_URL"

# Make scripts executable
chmod +x "${INSTALL_DIR}/heroic"
chmod +x "${INSTALL_DIR}/create_game_launchers.sh"
chmod +x "${INSTALL_DIR}/monitor_heroic.sh"

LAUNCHER="/userdata/system/add-ons/$APPNAME/Launcher"
cat <<EOL > "$LAUNCHER"
#!/bin/bash
/userdata/system/add-ons/heroic/extra/heroic-sync.sh &
unclutter-remote -s
DISPLAY=:0.0 /userdata/system/add-ons/heroic/heroic --no-sandbox "\$@"
EOL
chmod a+x "$LAUNCHER"

# Create launch script
echo "Creating launching script for Heroic..."
SYSTEM_LAUNCHER="/userdata/system/add-ons/$APPNAME/SystemLauncher"
cat <<EOL > "$SYSTEM_LAUNCHER"
#!/bin/bash
# Process input file
ID=\$(cat "\$1" | head -n 1)
# Execute application
unclutter-remote -s
DISPLAY=:0.0 /userdata/system/add-ons/heroic/heroic --no-sandbox --no-gui --disable-gpu "heroic://launch/\$ID"
EOL
chmod a+x "$SYSTEM_LAUNCHER"

# Create persistent desktop entry
echo "Creating persistent desktop entry for Heroic..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Heroic Games Launcher
Exec=$LAUNCHER
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
        <fullname>heroic</fullname>
        <name>heroic</name>
        <manufacturer>Linux</manufacturer>
        <release>2017</release>
        <hardware>console</hardware>
        <path>/userdata/roms/heroic</path>
        <extension>.TXT</extension>
        <command>/userdata/system/add-ons/heroic/SystemLauncher %ROM%</command>
        <platform>pc</platform>
        <theme>heroic</theme>
        <emulators>
            <emulator name="heroic">
                <cores>
                    <core default="true">heroic</core>
                </cores>
            </emulator>
        </emulators>
  </system>

</systemList>
EOF


# Final message
echo "Heroic Games Launcher setup complete! Installed version $HEROIC_VERSION."
echo "A desktop entry has been created and will persist across reboots."
echo "The system needs to reboot in order for Heroic to initialise, rebooting in..."
for i in {10..1}; do
    echo "$i"
    sleep 1
done
reboot


