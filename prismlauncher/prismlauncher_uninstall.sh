#!/bin/bash

echo "Uninstalling Prism Launcher..."

# Remove addon directory
rm -rf "/userdata/system/add-ons/prismlauncher"

# Remove desktop entries
rm -f "/usr/share/applications/prismlauncher.desktop"
rm -f "/userdata/system/configs/prismlauncher/prismlauncher.desktop"

# Remove configs and restore script
rm -rf "/userdata/system/configs/prismlauncher"

# Remove ports ROM entry
rm -f "/userdata/roms/ports/PrismLauncher.sh"
rm -f "/userdata/roms/ports/images/PrismLauncher-logo.png"

# Remove from gamelist.xml
GAMELIST="/userdata/roms/ports/gamelist.xml"
if [ -f "$GAMELIST" ]; then
    xmlstarlet ed -d "//game[path='./PrismLauncher.sh']" "$GAMELIST" \
        > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"
fi

# Remove from custom.sh
sed -i '\|/userdata/system/configs/prismlauncher/restore_desktop_entry.sh|d' \
    /userdata/system/custom.sh 2>/dev/null

echo "Prism Launcher uninstalled."
curl -s http://127.0.0.1:1234/reloadgames
