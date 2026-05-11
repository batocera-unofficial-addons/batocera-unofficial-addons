#!/bin/bash

echo "========================================="
echo "Uninstalling: ITGMania"
echo "========================================="
echo ""

# Remove addon directory
if [ -d "/userdata/system/add-ons/itgmania" ]; then
    echo "Removing /userdata/system/add-ons/itgmania"
    rm -rf "/userdata/system/add-ons/itgmania"
fi

# Remove ports launcher
if [ -f "/userdata/roms/ports/ITGMania.sh" ]; then
    echo "Removing /userdata/roms/ports/ITGMania.sh"
    rm -f "/userdata/roms/ports/ITGMania.sh"
fi

# Remove ports logo
if [ -f "/userdata/roms/ports/images/itgmania-logo.png" ]; then
    rm -f "/userdata/roms/ports/images/itgmania-logo.png"
fi

# Remove gamelist entry
if [ -f "/userdata/roms/ports/gamelist.xml" ]; then
    xmlstarlet ed -d "//game[path='./ITGMania.sh']" /userdata/roms/ports/gamelist.xml \
        > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml
fi

curl -s http://127.0.0.1:1234/reloadgames

echo ""
echo "========================================="
echo "Uninstallation complete: ITGMania"
echo "========================================="

killall -9 emulationstation
