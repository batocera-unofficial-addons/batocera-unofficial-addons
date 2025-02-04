#!/usr/bin/env bash

# Define application info
APPNAME="Java"
APPLINK="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/java/extra/"
APPHOME="azul.com/downloads"
INSTALL_DIR="/userdata/system/add-ons/${APPNAME,,}"

# Prepare installation directories
mkdir -p "$INSTALL_DIR/home" "$INSTALL_DIR/config" "$INSTALL_DIR/roms" "$INSTALL_DIR/extra"

# Display installation information
clear
echo -e "\033[1;32mInstalling ${APPNAME} Runtime for Batocera...\033[0m"
echo -e "Using source: $APPHOME"
echo -e "Installation directory: $INSTALL_DIR"
sleep 2

# Ensure system compatibility
if [[ "$(uname -m)" != "x86_64" ]]; then
    echo -e "\033[1;31mError: This installer requires Batocera x86_64.\033[0m"
    exit 1
fi

# Download Java Runtime package
TEMP_DIR="$INSTALL_DIR/extra/downloads"
mkdir -p "$TEMP_DIR"
echo -e "\033[1;34mDownloading Java Runtime...\033[0m"
curl --progress-bar --remote-name --location "${APPLINK}java.tar.bz2.partaa" -o "$TEMP_DIR/java.tar.bz2.partaa"
curl --progress-bar --remote-name --location "${APPLINK}java.tar.bz2.partab" -o "$TEMP_DIR/java.tar.bz2.partab"

# Merge and extract files
echo -e "\033[1;34mMerging and extracting Java Runtime...\033[0m"
cat "$TEMP_DIR/java.tar.bz2.parta"* > "$TEMP_DIR/java.tar.bz2"
tar -xjf "$TEMP_DIR/java.tar.bz2" -C "$INSTALL_DIR"
rm -rf "$TEMP_DIR"

# Set up environment variables
PROFILE_FILE="/userdata/system/.profile"
BASHRC_FILE="/userdata/system/.bashrc"
EXPORT_CMD='export PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java'

grep -qxF "$EXPORT_CMD" "$PROFILE_FILE" || echo "$EXPORT_CMD" >> "$PROFILE_FILE"
grep -qxF "$EXPORT_CMD" "$BASHRC_FILE" || echo "$EXPORT_CMD" >> "$BASHRC_FILE"

dos2unix "$PROFILE_FILE" "$BASHRC_FILE" 2>/dev/null

# Create a launcher script
LAUNCHER="$INSTALL_DIR/Launcher"
cat <<EOF > "$LAUNCHER"
#!/bin/bash
$EXPORT_CMD
java --version
echo "Java Runtime is ready."
sleep 4
EOF
chmod +x "$LAUNCHER"

echo -e "\033[1;32mJava Runtime installation complete!\033[0m"
