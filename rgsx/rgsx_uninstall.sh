#!/bin/bash
# Uninstaller for RGSX (third-party add-on by RetroGameSets, BUA)
# RGSX has no uninstaller of its own, so BUA ships this one.
# Removes RGSX from Ports, its gamelist entry, and the Windows (Retrobat)
# files its installer also unpacks into /userdata/roms/windows.
# RGSX settings and the games it downloaded are kept.

APP_NAME="RGSX"
PORTS="/userdata/roms/ports"
WINDOWS="/userdata/roms/windows"
GAME_LIST="$PORTS/gamelist.xml"

echo "========================================="
echo "Uninstalling: $APP_NAME"
echo "========================================="
echo ""

for DIR in "$PORTS/RGSX" "$PORTS/RGSX_INSTALL_LOGS"; do
  if [ -d "$DIR" ]; then
    echo "Removing folder: $DIR"
    rm -r "$DIR"
  fi
done

FILES=(
  "$PORTS/RGSX.sh"
  "$PORTS/images/RGSX.png"
  "$PORTS/videos/RGSX.mp4"
  "$WINDOWS/RGSX Retrobat.bat"
  "$WINDOWS/python.zip"
  "$WINDOWS/images/RGSX.png"
  "$WINDOWS/videos/RGSX.mp4"
  "$WINDOWS/scripts/rgsx_firewall_setup.ps1"
)
for FILE in "${FILES[@]}"; do
  if [ -e "$FILE" ]; then
    echo "Removing file: $FILE"
    rm -f "$FILE"
  fi
done
# Only removed when RGSX's script was the only thing in it
rmdir "$WINDOWS/scripts" 2>/dev/null

# Remove only RGSX's entry from the Ports gamelist (other games are kept)
if [ -f "$GAME_LIST" ]; then
  XPATH="/gameList/game[path='./RGSX/RGSX.sh' or path='./RGSX.sh']"
  if xmlstarlet sel -t -c "$XPATH" "$GAME_LIST" >/dev/null 2>&1; then
    echo "Removing $APP_NAME entry from $GAME_LIST"
    xmlstarlet ed -d "$XPATH" "$GAME_LIST" > "$GAME_LIST.tmp" \
      && mv "$GAME_LIST.tmp" "$GAME_LIST"
    rm -f "$GAME_LIST.tmp"
  fi
fi

# Refresh EmulationStation game lists
curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

echo ""
echo "Kept: RGSX settings (/userdata/saves/ports/rgsx) and the games it downloaded."
echo ""
echo "========================================="
echo "Uninstallation complete: $APP_NAME"
echo "========================================="
