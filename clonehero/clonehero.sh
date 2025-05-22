#!/bin/bash
# BATOCERA ADD-ONS INSTALLER

# Define app information
APPNAME="CloneHero"
APPLINK="https://github.com/clonehero-game/releases/releases/download/v1.1.0.4261-PTB/clonehero-linux.tar.xz"
APPDIR="/userdata/system/add-ons/${APPNAME,,}"

# Define launcher command

COMMAND='sysctl -w vm.max_map_count=2097152; ulimit -H -n 819200; ulimit -S -n 819200; ulimit -S -n 819200 clonehero; ulimit -H -l 61634; ulimit -S -l 61634; ulimit -H -s 61634; ulimit -S -s 61634; mkdir '$APPDIR'/home 2>/dev/null; mkdir '$APPDIR'/config 2>/dev/null; mkdir '$APPDIR'/roms 2>/dev/null; HOME='$APPDIR'/home XDG_CONFIG_HOME='$APPDIR'/config XDG_DATA_HOME='$APPDIR'/home XDG_CURRENT_DESKTOP=XFCE DESKTOP_SESSION=XFCE DISPLAY=:0.0 '$APPDIR'/'${APPNAME,,}' ${@}'

# Prepare installation directories
mkdir -p "$APPDIR/extra"
rm -rf "$APPDIR/*"

# Download and extract Clone Hero
TEMP_DIR="/tmp/${APPNAME,,}_download"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"
wget -q --show-progress -O "clonehero.tar.xz" "$APPLINK"
tar -xf "clonehero.tar.xz" -C "$APPDIR" --strip-components=1
chmod +x "$APPDIR/${APPNAME,,}"
rm -rf "$TEMP_DIR"

# Create launcher script
LAUNCHER="$APPDIR/Launcher"
echo "#!/bin/bash" > "$LAUNCHER"
echo "~/add-ons/.dep/mousemove.sh 2>/dev/null" >> "$LAUNCHER"
echo "$COMMAND" >> "$LAUNCHER"
chmod +x "$LAUNCHER"

# Create application shortcut
SHORTCUT="$APPDIR/extra/${APPNAME,,}.desktop"
echo "[Desktop Entry]" > "$SHORTCUT"
echo "Version=1.0" >> "$SHORTCUT"
echo "Icon=$APPDIR/extra/icon.png" >> "$SHORTCUT"
echo "Exec=$LAUNCHER" >> "$SHORTCUT"
echo "Terminal=false" >> "$SHORTCUT"
echo "Type=Application" >> "$SHORTCUT"
echo "Categories=Game;batocera.linux;" >> "$SHORTCUT"
echo "Name=$APPNAME" >> "$SHORTCUT"
cp "$SHORTCUT" "/usr/share/applications/${APPNAME,,}.desktop"

# Create Ports script
PORT_SCRIPT="/userdata/roms/ports/${APPNAME}.sh"
echo "#!/bin/bash" > "$PORT_SCRIPT"
echo "killall -9 ${APPNAME,,}" >> "$PORT_SCRIPT"
echo "$LAUNCHER" >> "$PORT_SCRIPT"
chmod +x "$PORT_SCRIPT"

# Add startup script
STARTUP_SCRIPT="$APPDIR/extra/startup"
echo "#!/usr/bin/env bash" > "$STARTUP_SCRIPT"
echo "cp $SHORTCUT /usr/share/applications/ 2>/dev/null" >> "$STARTUP_SCRIPT"
chmod +x "$STARTUP_SCRIPT"

# Ensure startup script runs at boot
CUSTOM_SH="/userdata/system/custom.sh"
if ! grep -Fxq "$STARTUP_SCRIPT" "$CUSTOM_SH"; then
    echo "$STARTUP_SCRIPT" >> "$CUSTOM_SH"
fi
chmod +x "$CUSTOM_SH"

# Refresh Ports menu
curl http://127.0.0.1:1234/reloadgames

# Download Clone Hero logo
LOGO_PATH="/userdata/roms/ports/images/CloneHero_Logo.png"
ICON_PATH="/$APPDIR/extra/icon.png"
curl -Ls -o "$ICON_PATH" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/clonehero/extra/icon.png"
curl -Ls -o "$LOGO_PATH" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/clonehero/extra/cloneherologo.png"

# Add logo to gamelist.xml
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
    -s "/gameList/game[last()]" -t elem -n "path" -v "./CloneHero.sh" \
    -s "/gameList/game[last()]" -t elem -n "name" -v "Clone Hero" \
    -s "/gameList/game[last()]" -t elem -n "image" -v "./images/CloneHero_Logo.png" \
    /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

curl http://127.0.0.1:1234/reloadgames

exit 0
