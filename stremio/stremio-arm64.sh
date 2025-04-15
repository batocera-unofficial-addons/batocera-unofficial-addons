#!/usr/bin/env bash

APPNAME="Stremio"
APPDIR="/userdata/system/add-ons/${APPNAME,,}"
APPBIN="${APPDIR}/stremio/stremio"
APPURL="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/stremio.tar.xz"  # ⬅️ Replace with your hosted URL
PORTIMG="https://blog.stremio.com/wp-content/uploads/2023/08/Stremio-logo-dark-background-1024x570.png"

# Check for Xwayland
if ! pgrep -x "Xwayland" > /dev/null; then
    echo "❌ Xwayland is not running. Exiting."
    exit 1
fi

echo "✅ Xwayland detected. Installing ${APPNAME}..."
sleep 2

# Prepare install directory
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/stremio" "${APPDIR}/extra" "${APPDIR}/home" "${APPDIR}/config" "${APPDIR}/roms"

# Download and extract app
ARCHIVE="${APPDIR}/stremio.tar.xz"
wget -q --show-progress -O "$ARCHIVE" "$APPURL"
tar -xJf "$ARCHIVE" -C "${APPDIR}"
rm -f "$ARCHIVE"

# Make binary executable
chmod +x "${APPBIN}" 2>/dev/null


# Create launcher script
cat <<EOF > "${APPDIR}/Launcher"
#!/bin/bash
batocera-mouse show
HOME="${APPDIR}/home" \\
XDG_CONFIG_HOME="${APPDIR}/config" \\
QT_SCALE_FACTOR="1" \\
GDK_SCALE="1" \\
XDG_DATA_HOME="${APPDIR}/home" \\
DISPLAY=:0.0 \\
"${APPBIN}" --no-sandbox "\$@"
EOF

chmod +x "${APPDIR}/Launcher"

# Create PORTS launcher
PORT_LAUNCHER="/userdata/roms/ports/Stremio.sh"
cat <<EOF > "$PORT_LAUNCHER"
#!/bin/bash
killall -9 stremio 2>/dev/null
batocera-mouse show
${APPDIR}/Launcher
EOF

chmod +x "$PORT_LAUNCHER"

# Create controller keys mapping
cat <<EOF > "${PORT_LAUNCHER}.keys"
{
    "actions_player1": [
        {
            "trigger": ["hotkey", "start"],
            "type": "key",
            "target": ["KEY_LEFTALT", "KEY_F4"]
        }
    ]
}
EOF

# Download the image
echo "Downloading Greenlight logo..."
curl -L -o /userdata/roms/ports/images/stremio.png "$PORTIMG"
echo "Adding logo to Stremio entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Stremio.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Stremio" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/stremio.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

echo "✅ ${APPNAME} installed and available under Ports and Applications!"
sleep 3
exit 0
