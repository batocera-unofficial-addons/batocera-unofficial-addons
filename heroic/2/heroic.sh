#!/bin/bash

# Define application variables
APPNAME="heroic"
APPLINK=$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases | grep AppImage | grep "browser_download_url" | head -n 1 | sed 's,^.*https://,https://,g' | cut -d '"' -f1)
APPHOME="github.com/Heroic-Games-Launcher"
APPPATH="/userdata/system/add-ons/$APPNAME/$APPNAME.AppImage"
EXTRA_PATH="/userdata/system/add-ons/$APPNAME/extra"
PRELAUNCHER_PATH="/userdata/system/add-ons/$APPNAME/extra/startup"
ES_CONFIG="/userdata/system/configs/emulationstation/es_systems_heroic.cfg"
PORTS_PATH="/userdata/roms/ports"
PROTON_PATH="/userdata/system/add-ons/$APPNAME/proton"


# Prepare directories
mkdir -p "/userdata/system/add-ons/$APPNAME" "$EXTRA_PATH" "$PROTON_PATH" "$PORTS_PATH" 2>/dev/null

# Display installer information
clear
echo -e "\n\nInstalling Heroic Launcher...\n"
echo "Using source: $APPHOME"
echo "Downloading from: $APPLINK"
sleep 1

# Download and install the AppImage
if curl -L --progress-bar "$APPLINK" -o "$APPPATH"; then
  echo "Heroic Launcher AppImage downloaded successfully."
else
  echo "Error: Failed to download Heroic Launcher." >&2
  exit 1
fi
chmod a+x "$APPPATH"

# Download and prepare Proton (in 3 parts)
PROTON_BASE="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/heroic/2"
echo "Downloading Proton parts..."
for part in partaa partab partac; do
  if ! curl -L --progress-bar "$PROTON_BASE/Proton-GE-Proton7-42.tar.xz.$part" -o "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz.$part"; then
    echo "Error: Failed to download Proton part $part." >&2
    exit 1
  fi
done
cat "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz.part"* > "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz"
if ! tar -xf "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz" -C "$PROTON_PATH" 2>/dev/null; then
  echo "Error: Failed to extract Proton." >&2
  exit 1
fi
rm -rf "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz" "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz.part"*

# Download create_game_launchers.sh
CREATE_LAUNCHERS_SCRIPT="$EXTRA_PATH/create_game_launchers.sh"
LAUNCHERS_SCRIPT_LINK="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/heroic/2/create_game_launchers.sh"
echo "Downloading create_game_launchers.sh..."
if ! curl -L --progress-bar "$LAUNCHERS_SCRIPT_LINK" -o "$CREATE_LAUNCHERS_SCRIPT"; then
  echo "Error: Failed to download create_game_launchers.sh." >&2
  exit 1
fi
chmod a+x "$CREATE_LAUNCHERS_SCRIPT"

# Download icon.png
ICON="$EXTRA_PATH/icon.png"
ICON_LINK="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/heroic/2/icon.png"
echo "Downloading Icon..."
if ! curl -L --progress-bar "$ICON_LINK" -o "$ICON"; then
  echo "Error: Failed to download icon." >&2
  exit 1
fi

# Create launcher script
LAUNCHER="/userdata/system/add-ons/$APPNAME/Launcher"
cat <<EOL > "$LAUNCHER"
#!/bin/bash
mkdir -p /userdata/system/add-ons/$APPNAME/home 2>/dev/null
mkdir -p /userdata/system/add-ons/$APPNAME/config 2>/dev/null

HOME=/userdata/system/add-ons/$APPNAME/home \
XDG_CONFIG_HOME=/userdata/system/add-ons/$APPNAME/config \
DISPLAY=:0.0 $APPPATH --no-sandbox "\$@"
EOL
chmod a+x "$LAUNCHER"

# Create SystemLauncher script
SYSTEM_LAUNCHER="/userdata/system/add-ons/$APPNAME/SystemLauncher"
cat <<EOL > "$SYSTEM_LAUNCHER"
#!/bin/bash
# Process input file
ID=\$(cat "\$1" | head -n 1)
# Execute application
unclutter-remote -s
mkdir -p /userdata/system/add-ons/$APPNAME/home 2>/dev/null
mkdir -p /userdata/system/add-ons/$APPNAME/config 2>/dev/null
HOME=/userdata/system/add-ons/$APPNAME/home \
XDG_DATA_HOME=/userdata/system/add-ons/$APPNAME/home \
XDG_CONFIG_HOME=/userdata/system/add-ons/$APPNAME/config \
LD_LIBRARY_PATH="/userdata/system/add-ons/.dep:\${LD_LIBRARY_PATH}" DISPLAY=:0.0 /userdata/system/add-ons/$APPNAME/$APPNAME.AppImage --no-sandbox --no-gui --disable-gpu "heroic://launch/\$ID"
EOL
chmod a+x "$SYSTEM_LAUNCHER"

# Create desktop shortcut
DESKTOP_FILE="/userdata/system/add-ons/$APPNAME/$APPNAME.desktop"
cat <<EOL > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=Heroic Launcher
Exec=$LAUNCHER
Icon=$EXTRA_PATH/icon.png
Terminal=false
Categories=Game;
EOL
chmod a+x "$DESKTOP_FILE"

# Copy desktop shortcut to system applications
cp "$DESKTOP_FILE" /usr/share/applications/ 2>/dev/null

PERSISTENT_DESKTOP="/usr/share/applications

# Ensure the desktop entry is always restored to /usr/share/applications
echo "Ensuring Heroic desktop entry is restored at startup..."
cat <<EOF > "/userdata/system/add-ons/heroic/restore_desktop_entry.sh"
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
bash /userdata/system/add-ons/heroic/restore_desktop_entry.sh &
EOF
chmod +x "/userdata/system/custom.sh"

# Add es_systems configuration
cat <<EOL > "$ES_CONFIG"
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
EOL

# Create Ports file
PORT_FILE="$PORTS_PATH/Heroic.sh"
cat <<EOL > "$PORT_FILE"
#!/bin/bash
unclutter-remote -s
HOME=/userdata/system/add-ons/$APPNAME/home \
XDG_DATA_HOME=/userdata/system/add-ons/$APPNAME/home \
XDG_CONFIG_HOME=/userdata/system/add-ons/$APPNAME/config \
DISPLAY=:0.0 /userdata/system/add-ons/$APPNAME/$APPNAME.AppImage --no-sandbox --disable-gpu
EOL
chmod a+x "$PORT_FILE"

# Add example ROM
ROM_PATH="/userdata/roms/heroic"
mkdir -p "$ROM_PATH" 2>/dev/null
EXAMPLE_ROM_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/heroic/2/FallGuys.txt"
EXAMPLE_ROM_FILE="$ROM_PATH/FallGuys.txt"
if ! curl -L --progress-bar "$EXAMPLE_ROM_URL" -o "$EXAMPLE_ROM_FILE"; then
  echo "Error: Failed to download example ROM." >&2
  exit 1
fi
dos2unix "$EXAMPLE_ROM_FILE" 2>/dev/null

# Cleanup temporary files
echo "Cleaning up temporary files..."
rm -rf "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz.part"*

# Display installed versions
PROTON_VERSION="$(cat "$PROTON_PATH/version" 2>/dev/null || echo 'unknown')"
echo -e "Heroic Launcher version: $(basename "$APPPATH")"
echo -e "Proton version: $PROTON_VERSION"

# Final output
echo -e "\nHeroic Launcher has been installed successfully.\n"
echo "Launcher is available in Ports or Applications menu."
echo "Prelauncher, Proton, SystemLauncher, create_game_launchers.sh, and example ROM have been set up."
