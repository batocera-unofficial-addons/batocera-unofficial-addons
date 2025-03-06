#!/bin/bash

# Detect system architecture
ARCH=$(uname -m)

# Define URLs for required files
ES_CFG_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/mame40/extra/es_systems_mame0139.cfg"
INFO_FILE_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/mame40/extra/mame0139_libretro.info"
CORE_FILE_URL_X86="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/mame40/extra/mame0139_libretro.so"
CORE_FILE_URL_ARM="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/mame40/extra/mame0139_libretro.so.aarch64"
CORE_FILE_2010_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/mame40/extra/mame2010_libretro.so"

# Define paths
BASE_DIR="/userdata/system/add-ons/mame2010"
EXTRA_DIR="$BASE_DIR/extra"
STARTUP_SCRIPT="$EXTRA_DIR/startup"
CUSTOM_SH="/userdata/system/custom.sh"
ES_CFG_PATH="/userdata/system/configs/emulationstation/es_systems_mame0139.cfg"
INFO_DEST="$BASE_DIR/mame0139_libretro.info"
CORE_DEST="$BASE_DIR/mame0139_libretro.so"
CORE_2010_DEST="$BASE_DIR/mame2010_libretro.so"

# Ensure required directories exist
mkdir -p "$EXTRA_DIR" /usr/share/libretro/info /usr/lib/libretro

# Download necessary files
wget -O "$ES_CFG_PATH" "$ES_CFG_URL" || { echo "Failed to download $ES_CFG_URL"; exit 1; }
wget -O "$INFO_DEST" "$INFO_FILE_URL" || { echo "Failed to download $INFO_FILE_URL"; exit 1; }

if [ "$ARCH" = "aarch64" ]; then
    echo "ARM64 detected. Running ARM setup..."
    wget -O "$CORE_DEST" "$CORE_FILE_URL_ARM" || { echo "Failed to download $CORE_FILE_URL_ARM"; exit 1; }
else
    if [ "$ARCH" != "x86_64" ]; then
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
    echo "x86_64 detected. Running x86_64 setup..."
    wget -O "$CORE_DEST" "$CORE_FILE_URL_X86" || { echo "Failed to download $CORE_FILE_URL_X86"; exit 1; }
    wget -O "$CORE_2010_DEST" "$CORE_FILE_2010_URL" || { echo "Failed to download $CORE_FILE_2010_URL"; exit 1; }
fi

# Set correct permissions
chmod 644 "$ES_CFG_PATH" "$INFO_DEST"
chmod 755 "$CORE_DEST" "$CORE_2010_DEST"

# Write the startup script dynamically
echo "#!/usr/bin/env bash" > "$STARTUP_SCRIPT"
echo "ln -sf $INFO_DEST /usr/share/libretro/info/mame0139_libretro.info" >> "$STARTUP_SCRIPT"
echo "ln -sf $CORE_DEST /usr/lib/libretro/mame0139_libretro.so" >> "$STARTUP_SCRIPT"

if [ "$ARCH" = "x86_64" ]; then
    echo "ln -sf $CORE_2010_DEST /usr/lib/libretro/mame2010_libretro.so" >> "$STARTUP_SCRIPT"
fi

# Symlink ROMs if user agrees
dialog --yesno "Do you want to link your existing /userdata/roms/mame folder to mame0139?" 12 60
if [ $? -eq 0 ]; then
    mkdir -p /userdata/roms/mame0139
    echo "ln -sf /userdata/roms/mame /userdata/roms/mame0139" >> "$STARTUP_SCRIPT"
else
    mkdir -p /userdata/roms/mame0139
fi

# Make the startup script executable
chmod +x "$STARTUP_SCRIPT"

# Ensure custom.sh includes startup script
if [ ! -f "$CUSTOM_SH" ]; then
    echo "#!/bin/bash" > "$CUSTOM_SH"
    chmod +x "$CUSTOM_SH"
fi

if ! grep -q "$STARTUP_SCRIPT" "$CUSTOM_SH"; then
    echo "bash $STARTUP_SCRIPT &" >> "$CUSTOM_SH"
fi

# Final message
dialog --title "Install Done" --msgbox "Setup complete! MAME 0.139 is installed. Reboot Batocera for changes to take effect. Update gamelists after reboot." 10 60

