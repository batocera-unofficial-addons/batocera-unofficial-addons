#!/bin/bash

# Paths
WINE_PATH="/usr/wine/ge-custom/bin/wine"
LAUNCHERS_DIR="/userdata/roms/heroic" # Path for Heroic game launchers
LOG_DIR="/userdata/system/.config/heroic/GamesConfig" # Directory containing game logs

# Ensure the launchers directory exists
mkdir -p "$LAUNCHERS_DIR"

# Fetch all lastPlay.log files
echo "Searching for lastPlay.log files in $LOG_DIR..."
LOG_FILES=$(find "$LOG_DIR" -type f -iname "*-lastPlay.log")

# Check if any log files are found
if [ -z "$LOG_FILES" ]; then
    echo "No lastPlay.log files found!"
    exit 1
fi

# Create a launcher for each game
echo "Creating launchers..."
echo "$LOG_FILES" | while read -r LOG_FILE; do
    # Extract the game name from the first line of the log file
    GAME_NAME=$(head -n 1 "$LOG_FILE" | awk -F'"' '{print $2}')

    if [ -z "$GAME_NAME" ]; then
        echo "Game name not found in $LOG_FILE, skipping..."
        continue
    fi

    # Replace spaces in the game name with underscores
    GAME_NAME=$(echo "$GAME_NAME" | tr ' ' '_')

    # Extract the launch command from the log file
    LAUNCH_COMMAND=$(grep "Launch Command:" "$LOG_FILE" | sed 's/Launch Command: //')

    if [ -z "$LAUNCH_COMMAND" ]; then
        echo "Launch command not found in $LOG_FILE for $GAME_NAME, skipping..."
        continue
    fi

    # Replace any existing --wine argument with the custom wine path
    LAUNCH_COMMAND=$(echo "$LAUNCH_COMMAND" | sed -E "s|--wine[ ]+[^ ]+|--wine \"$WINE_PATH\"|")

    # Use the sanitized game name for the launcher
    LAUNCHER_NAME="$GAME_NAME"
    LAUNCHER_PATH="${LAUNCHERS_DIR}/${LAUNCHER_NAME}.sh"

    # Create the launcher script
    cat <<EOF > "$LAUNCHER_PATH"
#!/bin/bash
export DISPLAY=:0.0
unclutter-remote -s

# Launch the game using the extracted command
$LAUNCH_COMMAND

# Wait for the game process (or anti-cheat) to stabilize
GAME_PID=\$!
while pgrep -f "$GAME_NAME" > /dev/null; do
    sleep 1
done

# Additional delay to ensure full initialization
sleep 5
EOF

    chmod +x "$LAUNCHER_PATH"
    echo "Launcher created: $LAUNCHER_PATH"
done

echo "All launchers have been created in $LAUNCHERS_DIR!"
