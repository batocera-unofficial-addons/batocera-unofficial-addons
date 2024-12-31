#!/usr/bin/env bash
######################################################################
# BATOCERA.UNOFFICIAL-ADDONS INSTALLER
######################################################################
APPNAME=MINECRAFT
appname=minecraft
AppName=Minecraft
APPPATH=/userdata/system/add-ons/$appname/$AppName
APPLINK=https://github.com/DTJW92/batocera-unofficial-addons/raw/main/minecraft/
LIBPATH=/userdata/system/add-ons/$appname/lib
IMAGEPATH=/userdata/system/add-ons/$appname
PORTSPATH=/userdata/roms/ports

# Output colors
W='\033[0;37m'
RED='\033[1;31m'
GREEN='\033[1;32m'
X='\033[0m'

# Console information
clear
echo
echo -e "${GREEN}Preparing $APPNAME Installer...${X}"

# Prepare directories
mkdir -p $LIBPATH 2>/dev/null
mkdir -p $IMAGEPATH 2>/dev/null
mkdir -p $PORTSPATH 2>/dev/null

# Download lib files and Minecraft AppImage
cd $LIBPATH
libs=("liblauncher.tar.bz2.partaa" "liblauncher.tar.bz2.partab" "liblauncher.tar.bz2.partac" "libselinux.so.1" "libsecret-1.so.0")

for lib in "${libs[@]}"; do
    echo -e "${GREEN}Downloading $lib...${X}"
    wget --progress=bar --no-check-certificate -q -O "$LIBPATH/$lib" "https://github.com/DTJW92/batocera-unofficial-addons/raw/main/minecraft/extra/lib/$lib"
    if [[ ! -f "$LIBPATH/$lib" ]]; then
        echo -e "${RED}Failed to download $lib. Aborting.${X}"
        exit 1
    fi
    echo -e "${GREEN}$lib downloaded successfully.${X}"
done

# Combine tar.bz2 parts and extract
cd $LIBPATH
if cat liblauncher.tar.bz2.part* > liblauncher.tar.bz2; then
    echo -e "${GREEN}Combining parts succeeded. Extracting...${X}"
    tar -xjf liblauncher.tar.bz2
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Extraction failed. Archive might be corrupted.${X}"
        exit 1
    fi
    chmod a+x $LIBPATH/liblauncher.so
    rm -f liblauncher.tar.bz2.part* liblauncher.tar.bz2
else
    echo -e "${RED}Failed to combine parts. Aborting.${X}"
    exit 1
fi

# Download Minecraft AppImage
cd $IMAGEPATH
echo -e "${GREEN}Downloading Minecraft AppImage...${X}"
wget --progress=bar --no-check-certificate -q -O "$IMAGEPATH/$AppName" "$APPLINK"
if [[ ! -f "$IMAGEPATH/$AppName" ]]; then
    echo -e "${RED}Failed to download Minecraft AppImage. Aborting.${X}"
    exit 1
fi
chmod a+x "$IMAGEPATH/$AppName"

# Download and place Minecraft.sh.keys
cd $PORTSPATH
echo -e "${GREEN}Downloading Minecraft.sh.keys...${X}"
wget --progress=bar --no-check-certificate -q -O "$PORTSPATH/Minecraft.sh.keys" "https://github.com/DTJW92/batocera-unofficial-addons/raw/main/minecraft/extra/Minecraft.sh.keys"
if [[ ! -f "$PORTSPATH/Minecraft.sh.keys" ]]; then
    echo -e "${RED}Failed to download Minecraft.sh.keys. Aborting.${X}"
    exit 1
fi

# Confirmation message
echo -e "${GREEN}Installation completed successfully.${X}"
echo -e "${GREEN}Files have been installed to $IMAGEPATH, $LIBPATH, and $PORTSPATH.${X}"
exit 0
