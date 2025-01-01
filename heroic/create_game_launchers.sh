#!/bin/bash

# Paths
LEGENDARY_PATH="/userdata/system/add-ons/heroic/resources/app.asar.unpacked/build/bin/x64/linux/legendary"
WINE_PATH="/usr/wine/ge-custom/bin/wine"
LAUNCHERS_DIR="/userdata/roms/heroic" # Updated path for Heroic game launchers

# Ensure the launchers directory exists
mkdir -p "$LAUNCHERS_DIR"

# Fetch the list of games from Legendary
echo "Fetching game list from Legendary..."
GAMES=$($LEGENDARY_PATH list | grep "App name:")

# Check if any games are installed
if [ -z "$GAMES" ]; then
    echo "No games found in Legendary!"
    exit 1
fi

# Create a launcher for each game
echo "Creating launchers..."
echo "$GAMES" | while read -r line; do
    GAME_NAME=$(echo "$line" | sed -E 's/.*: (.+) \(App name:.*/\1/' | tr -d ' ')
    APP_NAME=$(echo "$line" | sed -E 's/.*App name: ([^|]+).*/\1/')

    LAUNCHER_PATH="${LAUNCHERS_DIR}/${GAME_NAME}.sh"

    cat <<EOF > "$LAUNCHER_PATH"
#!/bin/bash
# Launch game with Legendary and Wine
"$LEGENDARY_PATH" launch "$APP_NAME" --wine "$WINE_PATH"
EOF

    chmod +x "$LAUNCHER_PATH"
    echo "Launcher created: $LAUNCHER_PATH"
done

echo "All launchers have been created in $LAUNCHERS_DIR!"
