#!/bin/bash
# Uninstaller for ps3i (third-party add-on by 8101987.xyz, BUA)
# ps3i's own site has no uninstaller, so BUA ships this one.
# Removes ps3i, its menu entry service and its file manager action.
# RPCS3 and installed PS3 games are kept.

APP_NAME="ps3i"
SERVICE="ps3i_menu_entry"
SERVICE_FILE="/userdata/system/services/$SERVICE"

echo "========================================="
echo "Uninstalling: $APP_NAME"
echo "========================================="
echo ""

# Stop the service first: it removes ps3i.desktop from the applications menu
if [ -x "$SERVICE_FILE" ]; then
  echo "Stopping service: $SERVICE"
  "$SERVICE_FILE" stop
fi
if command -v batocera-services >/dev/null 2>&1; then
  batocera-services disable "$SERVICE" >/dev/null 2>&1
fi
rm -f /usr/share/applications/ps3i.desktop

FILES=(
  "$SERVICE_FILE"
  "/userdata/system/bin/ps3i"
  "/userdata/system/.local/share/file-manager/actions/install-rpcs3.desktop"
)
for FILE in "${FILES[@]}"; do
  if [ -e "$FILE" ] || [ -L "$FILE" ]; then
    echo "Removing file: $FILE"
    rm -f "$FILE"
  fi
done

if [ -d /userdata/system/.local/ps3i ]; then
  echo "Removing folder: /userdata/system/.local/ps3i"
  rm -r /userdata/system/.local/ps3i
fi

echo ""
echo "Kept: RPCS3 and the PS3 games ps3i installed (/userdata/roms/ps3, /userdata/saves/ps3)."
echo ""
echo "========================================="
echo "Uninstallation complete: $APP_NAME"
echo "========================================="
