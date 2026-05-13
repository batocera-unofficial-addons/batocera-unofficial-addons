#!/bin/bash
# Uninstaller for Jellyfin Player

echo "========================================="
echo "Uninstalling: Jellyfin Player"
echo "========================================="
echo ""

# Remove AppImage
if [ -f "/userdata/system/add-ons/jellyfin-player/JellyfinPlayer.AppImage" ]; then
    echo "Removing AppImage..."
    rm -f "/userdata/system/add-ons/jellyfin-player/JellyfinPlayer.AppImage"
fi

# Remove Launcher
if [ -f "/userdata/system/add-ons/jellyfin-player/Launcher" ]; then
    echo "Removing Launcher..."
    rm -f "/userdata/system/add-ons/jellyfin-player/Launcher"
fi

# Remove ports launcher
if [ -f "/userdata/roms/ports/JellyfinPlayer.sh" ]; then
    echo "Removing port script..."
    rm -f "/userdata/roms/ports/JellyfinPlayer.sh"
fi

# Remove keys file
if [ -f "/userdata/roms/ports/JellyfinPlayer.sh.keys" ]; then
    echo "Removing keys file..."
    rm -f "/userdata/roms/ports/JellyfinPlayer.sh.keys"
fi

# Remove logo
if [ -f "/userdata/roms/ports/images/jellyfin-player-logo.jpg" ]; then
    echo "Removing logo..."
    rm -f "/userdata/roms/ports/images/jellyfin-player-logo.jpg"
fi

# Remove gamelist entry
if [ -f "/userdata/roms/ports/gamelist.xml" ] && command -v xmlstarlet &> /dev/null; then
    echo "Removing gamelist entry..."
    xmlstarlet ed --inplace \
        -d "/gameList/game[path='./JellyfinPlayer.sh']" \
        "/userdata/roms/ports/gamelist.xml"
fi

# Remove install directory
if [ -d "/userdata/system/add-ons/jellyfin-player" ]; then
    echo "Removing install directory..."
    rm -rf "/userdata/system/add-ons/jellyfin-player"
fi

# Reload Ports menu
curl -s http://127.0.0.1:1234/reloadgames > /dev/null

echo ""
echo "========================================="
echo "Uninstallation complete: Jellyfin Player"
echo "========================================="
