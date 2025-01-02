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
curl -L --progress-bar "$APPLINK" -o "$APPPATH"
chmod a+x "$APPPATH"

# Download and prepare Proton (in 3 parts)
PROTON_BASE="https://github.com/DTJW92/batocera-unofficial-addons/tree/main/heroic/2"
echo "Downloading Proton parts..."
for part in partaa partab partac; do
  curl -L --progress-bar "$PROTON_BASE/Proton-GE-Proton7-42.tar.xz.$part" -o "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz.$part"
done
cat "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz.part"* > "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz"
tar -xf "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz" -C "$PROTON_PATH" 2>/dev/null
rm -rf "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz" "$PROTON_PATH/Proton-GE-Proton7-42.tar.xz.part"*

# Download create_game_launchers.sh
CREATE_LAUNCHERS_SCRIPT="$EXTRA_PATH/create_game_launchers.sh"
LAUNCHERS_SCRIPT_LINK="https://github.com/DTJW92/batocera-unofficial-addons/tree/main/heroic/2/create_game_launchers.sh"
echo "Downloading create_game_launchers.sh..."
curl -L --progress-bar "$LAUNCHERS_SCRIPT_LINK" -o "$CREATE_LAUNCHERS_SCRIPT"
chmod a+x "$CREATE_LAUNCHERS_SCRIPT"

# Create launcher script
LAUNCHER="/userdata/system/add-ons/$APPNAME/Launcher"
cat <<EOL > "$LAUNCHER"
#!/bin/bash
mkdir -p /userdata/system/add-ons/$APPNAME/home 2>/dev/null
mkdir -p /userdata/system/add-ons/$APPNAME/config 2>/dev/null
# Solve dependencies on each run
dep=/userdata/system/add-ons/$APPNAME/extra; cd $dep; rm -rf $dep/dep 2>/dev/null
ls -l ./lib* | awk '{print $9}' | cut -d "/" -f2 >> $dep/dep 2>/dev/null
nl=$(cat $dep/dep | wc -l); l=1; while [[ $l -le $nl ]]; do
  lib=$(cat $dep/dep | sed ""$l"q;d"); ln -s $dep/$lib /lib/$lib 2>/dev/null; ((l++));
done
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
# Run sync script
/userdata/system/add-ons/$APPNAME/extra/heroic-sync.sh
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

# Create prelauncher script
cat <<EOL > "$PRELAUNCHER_PATH"
#!/bin/bash
cp "$DESKTOP_FILE" /usr/share/applications/ 2>/dev/null
done
EOL
chmod a+x "$PRELAUNCHER_PATH"

# Ensure prelauncher is added to system custom script for execution at boot
CUSTOM_SCRIPT="/userdata/system/custom.sh"
if ! grep -q "$PRELAUNCHER_PATH" "$CUSTOM_SCRIPT" 2>/dev/null; then
  echo "$PRELAUNCHER_PATH" >> "$CUSTOM_SCRIPT"
fi

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
        <command>/userdata/system/pro/heroic/SystemLauncher %ROM%</command>
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
/userdata/system/add-ons/$APPNAME/extra/heroic-sync.sh
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
EXAMPLE_ROM_URL="https://github.com/DTJW92/batocera-unofficial-addons/tree/main/heroic/2/FallGuys.txt"
EXAMPLE_ROM_FILE="$ROM_PATH/FallGuys.txt"
curl -L --progress-bar "$EXAMPLE_ROM_URL" -o "$EXAMPLE_ROM_FILE"
dos2unix "$EXAMPLE_ROM_FILE" 2>/dev/null

# Final output
echo -e "\nHeroic Launcher has been installed successfully.\n"
echo "Launcher is available in Ports or Applications menu."
