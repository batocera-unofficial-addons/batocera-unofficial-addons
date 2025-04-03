#!/bin/bash

# Set variables
APP_NAME="F1"
LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/f1/extra/f1key.jpg"   # Replace with actual logo URL
LOGO_PATH="./images/${APP_NAME,,}-logo.jpg"
GAME_LIST="/userdata/roms/ports/gamelist.xml"

# Step 1: Create the launcher script
echo "Creating ${APP_NAME}.sh..."
cat << 'EOF' > "${APP_NAME}.sh"
#!/bin/bash
filemanagerlauncher
EOF

chmod +x "${APP_NAME}.sh"

# Step 2: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl -s http://127.0.0.1:1234/reloadgames

# Step 3: Download the logo
echo "Downloading logo..."
mkdir -p ./images
curl -s -L -o "$LOGO_PATH" "$LOGO_URL"

# Step 4: Add entry to gamelist.xml
echo "Adding $APP_NAME to gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME,,}-logo.jpg" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"

# Step 5: Final refresh
curl -s http://127.0.0.1:1234/reloadgames

echo "Done! ${APP_NAME} has been added."
