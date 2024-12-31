#!/usr/bin/env bash
######################################################################
# BATOCERA.UNOFFICIAL-ADDONS INSTALLER
######################################################################
APPNAME=MINECRAFT
appname=minecraft
AppName=Minecraft
APPPATH=/userdata/system/add-ons/$appname/$AppName
APPLINK=https://github.com/DTJW92/batocera-unofficial-addons/raw/main/minecraft/extra/Minecraft
LIBPATH=/userdata/system/add-ons/$appname/lib
IMAGEPATH=/userdata/system/add-ons/$appname

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

# Download lib files and Minecraft AppImage
cd $LIBPATH
libs=("liblauncher.tar.bz2.partaa" "liblauncher.tar.bz2.partab" "liblauncher.tar.bz2.partac" "libselinux.so.1" "libsecret-1.so.0")

for lib in "${libs[@]}"; do
    echo -e "${GREEN}Downloading $lib...${X}"
    wget --progress=bar --no-check-certificate -q -O "$LIBPATH/$lib" "https://github.com/DTJW92/batocera-unofficial-addons/raw/main/minecraft/extra/$lib"
done

# Combine tar.bz2 parts and extract
cd $LIBPATH
cat liblauncher.tar.bz2.part* > liblauncher.tar.bz2
pro=/userdata/system/add-ons
mkdir -p $pro/.dep 2>/dev/null
chmod a+x $pro/.dep/tar
$pro/.dep/tar -xf liblauncher.tar.bz2
chmod a+x $LIBPATH/liblauncher.so
rm -f liblauncher.tar.bz2.part* liblauncher.tar.bz2

# Download Minecraft AppImage
cd $IMAGEPATH
echo -e "${GREEN}Downloading Minecraft AppImage...${X}"
wget --progress=bar --no-check-certificate -q -O "$IMAGEPATH/$AppName" "$APPLINK"
chmod a+x "$IMAGEPATH/$AppName"

# Confirmation message
echo -e "${GREEN}Installation completed successfully.${X}"
echo -e "${GREEN}Files have been installed to $IMAGEPATH and $LIBPATH.${X}"
exit 0
