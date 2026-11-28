#!/bin/bash
# Uninstaller for SHRUBNAUT (Windows freeware, BUA)
# Removes the game package, its gamelist entry and its logo.
# Saves and Wine settings are kept.

APP_NAME="SHRUBNAUT"
GAME_LIST="/userdata/roms/windows/gamelist.xml"
ROM_FILE="SHRUBNAUT.wsquashfs"
FILES=(
  "/userdata/roms/windows/SHRUBNAUT.wsquashfs"
  "/userdata/roms/windows/images/SHRUBNAUT-logo.png"
)

echo "========================================="
echo "Uninstalling: $APP_NAME"
echo "========================================="
echo ""

# Remove the files the installer downloaded
for FILE in "${FILES[@]}"; do
  if [ -e "$FILE" ]; then
    echo "Removing file: $FILE"
    rm -f "$FILE"
  fi
done

# Remove the game's entry from the Windows gamelist (other games are kept)
if [ -f "$GAME_LIST" ]; then
  if xmlstarlet sel -t -c "/gameList/game[path='./$ROM_FILE']" "$GAME_LIST" >/dev/null 2>&1; then
    echo "Removing $APP_NAME entry from $GAME_LIST"
    xmlstarlet ed -d "/gameList/game[path='./$ROM_FILE']" "$GAME_LIST" > "$GAME_LIST.tmp" \
      && mv "$GAME_LIST.tmp" "$GAME_LIST"
    rm -f "$GAME_LIST.tmp"
  fi
fi

# Refresh EmulationStation game lists
curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

echo ""
echo "Kept: saves and Wine settings for this game (if it was ever launched):"
echo "  /userdata/saves/windows/"
echo "  /userdata/system/wine-bottles/windows/<wine version>/$ROM_FILE.wine"
echo ""
echo "========================================="
echo "Uninstallation complete: $APP_NAME"
echo "========================================="
