#!/bin/bash

# Paths
SHADPS4_EXEC="/userdata/system/add-ons/shadps4/shadps4plus.AppImage"
CREATE_LAUNCHERS_SCRIPT="/userdata/system/add-ons/shadps4/create_game_launchers.sh"

# Function to check if ShadPS4 is running
is_shadps4_running() {
    pgrep -f "$SHADPS4_EXEC" > /dev/null
}

echo "Monitoring ShadPS4 process..."

# Wait for ShadPS4 to start
echo "Waiting for ShadPS4 to start..."
until is_shadps4_running; do
    sleep 10
done

# Loop while ShadPS4 is running
while true; do
    if is_shadps4_running; then
        echo "ShadPS4 is running. Checking launchers..."
        "$CREATE_LAUNCHERS_SCRIPT"
        sleep 1 # Wait for 1 second before checking again
    else
        echo "ShadPS4 is not running. Exiting."
        curl http://127.0.0.1:1234/reloadgames
        break
    fi
done
