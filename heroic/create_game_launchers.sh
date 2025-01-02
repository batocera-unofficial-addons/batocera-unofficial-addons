#!/bin/bash

# Paths
LEGENDARY_PATH="/userdata/system/add-ons/heroic/resources/app.asar.unpacked/build/bin/x64/linux/legendary"
WINE_PATH="/usr/wine/ge-custom/bin/wine"
LAUNCHERS_DIR="/userdata/roms/heroic" # Path for Heroic game launchers
GAMES_DIR="/userdata/system/Games/Heroic" # Base directory for installed games
LOG_DIR="/userdata/system/.config/heroic/GamesConfig" # Directory containing game logs

# Ensure the launchers directory exists
mkdir -p "$LAUNCHERS_DIR"

# Ensure the Legendary config symlink exists
echo "Ensuring Legendary config symlink is correctly set..."
rm -rf /userdata/system/.config/legendary
ln -sf /userdata/system/.config/heroic/legendaryConfig/legendary /userdata/system/.config/legendary
echo "Legendary config symlink recreated."

# Fetch the list of games from Legendary
echo "Fetching game list from Legendary..."
GAMES=$($LEGENDARY_PATH list-installed | grep "App name:")

# Check if any games are installed
if [ -z "$GAMES" ]; then
    echo "No games found in Legendary!"
    exit 1
fi

# Create a launcher for each game
echo "Creating launchers..."
echo "$GAMES" | while read -r line; do
    GAME_NAME=$(echo "$line" | sed -E 's/^[* ]*(.+) \(App name:.*/\1/' | tr -d ' ')
    APP_NAME=$(echo "$line" | sed -E 's/.*App name: ([^|]+).*/\1/' | tr -d ' ')

    # Debug log for GAME_NAME and APP_NAME
    echo "Processing game: GAME_NAME='$GAME_NAME', APP_NAME='$APP_NAME'"

    # Locate the log file
    LOG_FILE=$(find "$LOG_DIR" -type f -iname "${APP_NAME}-lastPlay.log" | head -n 1)

    if [ -z "$LOG_FILE" ]; then
        echo "Log file not found for $GAME_NAME, skipping..."
        continue
    fi

    # Extract the launch command from the log file
    LAUNCH_COMMAND=$(grep "Launch Command:" "$LOG_FILE" | sed 's/Launch Command: //' | sed 's/--wine[^ ]* /--wine \"\/usr\/wine\/ge-custom\/bin\/wine\" /')

    if [ -z "$LAUNCH_COMMAND" ]; then
        echo "Launch command not found in log file for $GAME_NAME, skipping..."
        continue
    fi

    # Use the actual directory name for the launcher
    LAUNCHER_NAME="$GAME_NAME"
    LAUNCHER_PATH="${LAUNCHERS_DIR}/${LAUNCHER_NAME}.sh"

    # Create the launcher script
    cat <<EOF > "$LAUNCHER_PATH"
#!/bin/bash
export DISPLAY=:0.0

# Launch the game using the extracted command
$LAUNCH_COMMAND &

# Add a delay to wait for the game to fully initialize
wait
EOF


    chmod +x "$LAUNCHER_PATH"
    echo "Launcher created: $LAUNCHER_PATH"
done

echo "All launchers have been created in $LAUNCHERS_DIR!"
