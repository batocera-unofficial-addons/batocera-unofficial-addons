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
tar -xJf "$ARCHIVE" -C "${APPDIR}/stremio"
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
killall -9 stremio-wrapper 2>/dev/null
batocera-mouse show
${APPDIR}/Launcher
EOF

chmod +x "$PORT_LAUNCHER"
cp "${APPDIR}/extra/stremio.png" "/userdata/roms/ports/Stremio.png"

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

echo "✅ ${APPNAME} installed and available under Ports and Applications!"
exit 0
