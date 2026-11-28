#!/bin/bash
# Uninstaller for iso2zar (third-party add-on by 8101987.xyz, BUA)
# iso2zar has no uninstaller of its own, so BUA ships this one.
# Removes iso2zar, its links in /userdata/system/bin and its menu entry service.
# Kept: the files you converted with iso2zar.

APP_NAME="iso2zar"
SERVICE="iso2zar_menu_entry"
SERVICE_FILE="/userdata/system/services/$SERVICE"

echo "========================================="
echo "Uninstalling: $APP_NAME"
echo "========================================="
echo ""

# Stop the service first: it removes iso2zar.desktop from the applications menu
if [ -x "$SERVICE_FILE" ]; then
  echo "Stopping service: $SERVICE"
  "$SERVICE_FILE" stop
fi
if command -v batocera-services >/dev/null 2>&1; then
  batocera-services disable "$SERVICE" >/dev/null 2>&1
fi
rm -f /usr/share/applications/iso2zar.desktop

FILES=(
  "$SERVICE_FILE"
  "/userdata/system/bin/iso2zar"
)
for FILE in "${FILES[@]}"; do
  if [ -e "$FILE" ] || [ -L "$FILE" ]; then
    echo "Removing file: $FILE"
    rm -f "$FILE"
  fi
done

if [ -d /userdata/system/.local/iso2zar ]; then
  echo "Removing folder: /userdata/system/.local/iso2zar"
  rm -r /userdata/system/.local/iso2zar
fi

echo ""
echo "Kept: the files you converted with iso2zar."
echo ""
echo "========================================="
echo "Uninstallation complete: $APP_NAME"
echo "========================================="
