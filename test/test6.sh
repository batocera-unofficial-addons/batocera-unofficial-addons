#!/usr/bin/env bash

######################################################################
# VIBER INSTALLER FOR BATOCERA ADD-ONS
######################################################################

# Define the application name and paths
APPNAME="Viber"
APPPATH="/userdata/system/add-ons/${APPNAME,,}/${APPNAME,,}.AppImage"
APPLINK="https://download.cdn.viber.com/desktop/Linux/viber.AppImage"
ORIGIN="VIBER.COM"

# Clear the screen and display preparation message
clear
echo -e "\n\nPREPARING $APPNAME INSTALLER, PLEASE WAIT...\n\n"

# Prepare required directories
BASE_DIR="/userdata/system/add-ons/${APPNAME,,}"
mkdir -p "$BASE_DIR/extra"

# Download the application
TEMP_DIR="${BASE_DIR}/extra/downloads"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
echo -e "\nDOWNLOADING $APPNAME..."
curl --progress-bar --location -o "$TEMP_DIR/${APPNAME,,}.AppImage" "$APPLINK"
mv "$TEMP_DIR/${APPNAME,,}.AppImage" "$APPPATH"
chmod a+x "$APPPATH"
rm -rf "$TEMP_DIR"

# Create launcher script
LAUNCHER="${BASE_DIR}/Launcher"
cat <<EOF > "$LAUNCHER"
#!/bin/bash
unclutter-remote -s
HOME=/userdata/system/add-ons/${APPNAME,,}/home \
XDG_CONFIG_HOME=/userdata/system/add-ons/${APPNAME,,}/config \
QT_SCALE_FACTOR="1.25" \
GDK_SCALE="1.25" \
"$APPPATH" --no-sandbox "\$@"
EOF
chmod a+x "$LAUNCHER"

# Download application icon
ICON_PATH="${BASE_DIR}/extra/icon.png"
curl -s -o "$ICON_PATH" "https://github.com/trashbus99/profork/raw/master/${APPNAME,,}/extra/icon.png"

# Create desktop shortcut
SHORTCUT="${BASE_DIR}/extra/${APPNAME,,}.desktop"
cat <<EOF > "$SHORTCUT"
[Desktop Entry]
Version=1.0
Icon=$ICON_PATH
Exec=$LAUNCHER
Terminal=false
Type=Application
Categories=Game;batocera.linux;
Name=$APPNAME
EOF
cp "$SHORTCUT" "/usr/share/applications/${APPNAME,,}.desktop"

# Prepare startup script
PRESTART_SCRIPT="${BASE_DIR}/extra/startup"
cat <<EOF > "$PRESTART_SCRIPT"
#!/usr/bin/env bash
cp "$SHORTCUT" /usr/share/applications/ 2>/dev/null
EOF
chmod a+x "$PRESTART_SCRIPT"

# Add startup script to custom.sh
CUSTOM_SCRIPT="/userdata/system/custom.sh"
if ! grep -Fxq "$PRESTART_SCRIPT" "$CUSTOM_SCRIPT"; then
  echo "$PRESTART_SCRIPT" >> "$CUSTOM_SCRIPT"
fi

# Final installation message
echo -e "\n$APPNAME INSTALLATION COMPLETE.\n"
exit 0
