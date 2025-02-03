#!/usr/bin/env bash

# Define App Info
APPNAME="Java"

# Define Paths
APPDIR=/userdata/system/add-ons/${APPNAME,,}
mkdir -p "$APPDIR/home" "$APPDIR/config" "$APPDIR/roms" "$APPDIR/extra"

# Define Launcher Command
COMMAND="HOME=$APPDIR/home XDG_CONFIG_HOME=$APPDIR/config XDG_DATA_HOME=$APPDIR/home DISPLAY=:0.0 $APPDIR/${APPNAME,,}.AppImage --no-sandbox"

# Prepare Installer
clear
echo "PREPARING $APPNAME INSTALLER, PLEASE WAIT..."
sleep 1

# Download and Install Java
INSTALL_DIR=/userdata/system/add-ons/${APPNAME,,}
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

curl --progress-bar --remote-name --location "https://github.com/DTJW92/batocera-unofficial-addons/raw/main/${APPNAME,,}/extra/java.tar.bz2.partaa"
curl --progress-bar --remote-name --location "https://github.com/DTJW92/batocera-unofficial-addons/raw/main/${APPNAME,,}/extra/java.tar.bz2.partab"
cat java.tar.bz2.parta* > java.tar.bz2
tar -xf java.tar.bz2
rm java.tar.bz2 java.tar.bz2.parta*

# Download and Set Up Icon
ICON_PATH="$INSTALL_DIR/extra/icon.png"
curl --progress-bar --remote-name --location "https://github.com/DTJW92/batocera-unofficial-addons/raw/main/${APPNAME,,}/extra/icon.png" -o "$ICON_PATH"

# Configure Environment Variables
echo 'export PATH=/userdata/system/add-ons/java/bin:$PATH' >> /userdata/system/.profile
echo 'export JAVA_HOME=/userdata/system/add-ons/java' >> /userdata/system/.profile
dos2unix /userdata/system/.profile

# Create Launcher Script
LAUNCHER="$INSTALL_DIR/Launcher"
cat << EOF > "$LAUNCHER"
#!/bin/bash
export JAVA_HOME=/userdata/system/add-ons/java
DISPLAY=:0.0 xterm -fullscreen -bg black -fa 'Monospace' -fs 12 -e bash -c "java --version"
EOF
chmod +x "$LAUNCHER"

# Create Desktop Shortcut
DESKTOP_FILE="/userdata/system/add-ons/${APPNAME,,}/extra/${APPNAME,,}.desktop"
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Icon=$INSTALL_DIR/extra/icon.png
Exec=$LAUNCHER
Terminal=false
Type=Application
Categories=Game;batocera.linux;
Name=$APPNAME
EOF
chmod +x "$DESKTOP_FILE"
cp "$DESKTOP_FILE" /usr/share/applications/

# Setup Startup Script
STARTUP_SCRIPT="$INSTALL_DIR/extra/startup"
cat << EOF > "$STARTUP_SCRIPT"
#!/usr/bin/env bash
cp $DESKTOP_FILE /usr/share/applications/
EOF
chmod +x "$STARTUP_SCRIPT"
echo "$STARTUP_SCRIPT" >> /userdata/system/custom.sh
chmod +x /userdata/system/custom.sh

echo "$APPNAME INSTALLATION COMPLETE!"
