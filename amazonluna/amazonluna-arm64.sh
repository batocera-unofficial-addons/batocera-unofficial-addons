#!/usr/bin/env bash

APPNAME="Amazon-Luna"
APPDIR="/userdata/system/add-ons/${APPNAME,,}"
APPBIN="${APPDIR}/luna/amazonluna"
APPURL="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/luna.tar.xz"
ICONURL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/amazonluna/extra/lunaicon.png"
PORTIMG="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/amazonluna/extra/amazonluna.png"

# Check for Xwayland
if ! pgrep -x "Xwayland" > /dev/null; then
    echo "❌ Xwayland is not running. Exiting."
    exit 1
fi

echo "✅ Xwayland detected. Installing ${APPNAME}..."
sleep 2

# Prepare install directory
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/luna" "${APPDIR}/extra" "${APPDIR}/home" "${APPDIR}/config" "${APPDIR}/roms"

# Download and extract app
ARCHIVE="${APPDIR}/luna.tar.xz"
wget -q --show-progress -O "$ARCHIVE" "$APPURL"
tar -xJf "$ARCHIVE" -C "${APPDIR}/luna"
rm -f "$ARCHIVE"

# Make binary executable
chmod +x "${APPBIN}" 2>/dev/null

# Download icons
wget -q -O "${APPDIR}/extra/icon.png" "$ICONURL"

# Create launcher script
cat <<EOF > "${APPDIR}/Launcher"
#!/bin/bash
unclutter-remote -s
HOME="${APPDIR}/home" \\
XDG_CONFIG_HOME="${APPDIR}/config" \\
QT_SCALE_FACTOR="1" \\
GDK_SCALE="1" \\
XDG_DATA_HOME="${APPDIR}/home" \\
DISPLAY=:0.0 \\
"${APPBIN}" --no-sandbox "\$@"
EOF

chmod +x "${APPDIR}/Launcher"

# Create F1 Applications shortcut
DESKTOP="${APPDIR}/extra/luna.desktop"
cat <<EOF > "$DESKTOP"
[Desktop Entry]
Version=1.0
Name=Amazon Luna
Exec=${APPDIR}/Launcher
Icon=${APPDIR}/extra/icon.png
Terminal=false
Type=Application
Categories=Game;batocera.linux;
EOF

chmod +x "$DESKTOP"
cp "$DESKTOP" "/usr/share/applications/luna.desktop" 2>/dev/null

# Create PORTS launcher
PORT_LAUNCHER="/userdata/roms/ports/AmazonLuna.sh"
cat <<EOF > "$PORT_LAUNCHER"
#!/bin/bash
killall -9 amazonluna 2>/dev/null
unclutter-remote -s
${APPDIR}/Launcher
EOF

chmod +x "$PORT_LAUNCHER"

# Create controller keys mapping
cat <<EOF > "${PORT_LAUNCHER}.keys"
{
    "actions_player1": [
        {
            "trigger": [
                "hotkey",
                "start"
            ],
            "type": "key",
            "target": [
                "KEY_LEFTALT",
                "KEY_F4"
            ]
        }
    ]
}
EOF

# Add to autostart via custom.sh
STARTUP="${APPDIR}/extra/startup"
echo "#!/bin/bash" > "$STARTUP"
echo "cp \"$DESKTOP\" /usr/share/applications/ 2>/dev/null" >> "$STARTUP"
chmod +x "$STARTUP"

CUSTOM_SH="/userdata/system/custom.sh"
grep -qxF "$STARTUP" "$CUSTOM_SH" 2>/dev/null || echo "$STARTUP" >> "$CUSTOM_SH"
chmod +x "$CUSTOM_SH"

# Step 5: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the image
echo "Downloading Amazon Luna logo..."
curl -L -o /userdata/roms/ports/images/amazonluna.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/amazonluna/extra/amazonluna.png
echo "Adding logo to Amazon Luna entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./AmazonLuna.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Amazon Luna" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/amazonluna.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml
  
curl http://127.0.0.1:1234/reloadgames

echo "✅ Amazon Luna installed and available under Ports and Applications!"
exit 0
