#!/bin/bash
# Uninstaller for npsget (third-party add-on by 8101987.xyz, BUA)
# npsget has no uninstaller of its own, so BUA ships this one.
# Removes npsget, its links in /userdata/system/bin and its menu entry service.
# Kept: the games and files npsget downloaded.

APP_NAME="npsget"
SERVICE="npsget_menu_entry"
SERVICE_FILE="/userdata/system/services/$SERVICE"

echo "========================================="
echo "Uninstalling: $APP_NAME"
echo "========================================="
echo ""

# Stop the service first: it removes npsget.desktop from the applications menu
if [ -x "$SERVICE_FILE" ]; then
  echo "Stopping service: $SERVICE"
  "$SERVICE_FILE" stop
fi
if command -v batocera-services >/dev/null 2>&1; then
  batocera-services disable "$SERVICE" >/dev/null 2>&1
fi
rm -f /usr/share/applications/npsget.desktop

FILES=(
  "$SERVICE_FILE"
  "/userdata/system/bin/npsget"
  "/userdata/system/bin/npsget-cli"
  "/userdata/system/bin/npsget-tui"
  "/userdata/system/bin/npsget-gui"
  "/userdata/system/.local/share/man/man1/npsget.1.gz"
)
for FILE in "${FILES[@]}"; do
  if [ -e "$FILE" ] || [ -L "$FILE" ]; then
    echo "Removing file: $FILE"
    rm -f "$FILE"
  fi
done

if [ -d /userdata/system/.local/npsget ]; then
  echo "Removing folder: /userdata/system/.local/npsget"
  rm -r /userdata/system/.local/npsget
fi

echo ""
echo "Kept: the games and files npsget downloaded."
echo ""
echo "========================================="
echo "Uninstallation complete: $APP_NAME"
echo "========================================="
