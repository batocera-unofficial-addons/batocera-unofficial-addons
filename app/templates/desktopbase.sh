DESKTOP_FILE="/usr/share/applications/{$APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/{$APPNAME,,}/{APPNAME}.desktop"
ICON_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/{APPNAME,,}/extra/icon.png"

# Create persistent desktop entry
echo "Creating persistent desktop entry for {APPNAME}..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name={APPNAME}
Exec=/userdata/roms/ports/{APPNAME}.sh
Icon=/userdata/system/add-ons/{APPNAME,,}/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored to /usr/share/applications
echo "Ensuring {APPNAME} desktop entry is restored at startup..."
cat <<EOF > "/userdata/system/configs/{APPNAME,,}/restore_desktop_entry.sh"
#!/bin/bash
# Restore {APPNAME} desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring {APPNAME} desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "{APPNAME} desktop entry restored."
else
    echo "{APPNAME} desktop entry already exists."
fi
EOF
chmod +x "/userdata/system/configs/{APPNAME,,}/restore_desktop_entry.sh"

# Add to startup script
custom_startup="/userdata/system/custom.sh"
if ! grep -q "/userdata/system/configs/{APPNAME,,}/restore_desktop_entry.sh" "$custom_startup"; then
    echo "Adding {APPNAME} restore script to startup..."
    echo "bash "/userdata/system/configs/{APPNAME,,}/restore_desktop_entry.sh" &" >> "$custom_startup"
fi
chmod +x "$custom_startup"
