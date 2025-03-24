#!/usr/bin/env bash

# Define App Info
APPNAME=java
APPHOME=azul.com/downloads
APPPATH=/userdata/system/add-ons/$APPNAME/$APPNAME.AppImage

# Define Launcher Command
COMMAND='mkdir -p /userdata/system/add-ons/'$APPNAME'/home /userdata/system/add-ons/'$APPNAME'/config /userdata/system/add-ons/'$APPNAME'/roms 2>/dev/null; \
HOME=/userdata/system/add-ons/'$APPNAME'/home XDG_CONFIG_HOME=/userdata/system/add-ons/'$APPNAME'/config QT_SCALE_FACTOR="1" GDK_SCALE="1" XDG_DATA_HOME=/userdata/system/add-ons/'$APPNAME'/home DISPLAY=:0.0 /userdata/system/add-ons/'$APPNAME'/'$APPNAME'.AppImage --no-sandbox'

# Prepare Paths and Files
mkdir -p /userdata/system/add-ons/$APPNAME/extra
echo "$COMMAND" > /userdata/system/add-ons/$APPNAME/extra/command

# Download Necessary Files
curl -s -Lo /userdata/system/add-ons/$APPNAME/extra/icon.png \
    https://github.com/DTJW92/batocera-unofficial-addons/raw/main/$APPNAME/extra/icon.png || { echo "Download failed! Exiting..."; exit 1; }

# Check System Compatibility
if ! uname -a | grep -q 'x86_64'; then 
    echo "ERROR: SYSTEM NOT SUPPORTED. You need Batocera x86_64."
    exit 1
fi

# Download Java Runtime
mkdir -p /userdata/system/add-ons/$APPNAME/extra/downloads
cd /userdata/system/add-ons/$APPNAME/extra/downloads

for part in java.tar.bz2.partaa java.tar.bz2.partab; do
    curl -s --progress-bar --remote-name --location \
        https://github.com/DTJW92/batocera-unofficial-addons/raw/main/$APPNAME/extra/$part || { echo "Download failed! Exiting..."; exit 1; }
done

# Merge and Extract Java Files
cat java.tar.bz2.parta* > java.tar.gz
mkdir -p /userdata/system/add-ons/java
tar -xjf java.tar.gz --strip-components=1 -C /userdata/system/add-ons/java

# Update Profile and Bashrc
for file in /userdata/system/.profile /userdata/system/.bashrc; do
    if [[ -f "$file" ]]; then
        grep -qxF 'export PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java' "$file" || \
        echo 'export PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java' >> "$file"
    else
        echo 'export PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java' >> "$file"
    fi
done

# Create Launcher Script
LAUNCHER=/userdata/system/add-ons/$APPNAME/Launcher
cat <<EOF > $LAUNCHER
#!/bin/bash
export PATH=/userdata/system/add-ons/java/bin:\$PATH
export JAVA_HOME=/userdata/system/add-ons/java

if command -v java &> /dev/null; then
    java --version
else
    echo "Java not found! Installation might have failed."
fi
EOF
chmod +x $LAUNCHER

# Create Application Shortcut
DESKTOP_ENTRY=/userdata/system/add-ons/$APPNAME/extra/$APPNAME.desktop
cat <<EOF > $DESKTOP_ENTRY
[Desktop Entry]
Version=1.0
Icon=/userdata/system/add-ons/$APPNAME/extra/icon.png
Exec=/userdata/system/add-ons/$APPNAME/Launcher
Terminal=false
Type=Application
Categories=Game;batocera.linux;
Name=$APPNAME
EOF
chmod +x $DESKTOP_ENTRY
cp $DESKTOP_ENTRY /usr/share/applications/ 2>/dev/null

# Auto-run on Boot
CUSTOM_SH=/userdata/system/custom.sh
if ! grep -q "/userdata/system/add-ons/$APPNAME/extra/startup" "$CUSTOM_SH"; then
    echo -e "\n/userdata/system/add-ons/$APPNAME/extra/startup" >> "$CUSTOM_SH"
fi
chmod +x "$CUSTOM_SH"

# Final Output
echo "$APPNAME installation complete."
