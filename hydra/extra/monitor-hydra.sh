#!/bin/bash

# Path to the setup script
SETUP_SCRIPT="/userdata/system/add-ons/hydra/extra/aria2-sync.sh"

# Initial delay to allow Hydra to initialize
echo "Waiting 10 seconds before starting monitoring..."
sleep 10

# Function to start the setup script
start_symlink_script() {
    if ! pgrep -f "aria2c --enable-rpc" > /dev/null; then
        echo "Starting aria2 setup script..."
        $SETUP_SCRIPT &
        SETUP_PID=$!
    else
        echo "aria2c is already running."
    fi
}

# Function to stop the aria2c process and cleanup
stop_symlink_script() {
    echo "Stopping aria2c process..."
    pkill -f "aria2c --enable-rpc" 2>/dev/null
    if [ -n "$SETUP_PID" ]; then
        kill "$SETUP_PID" 2>/dev/null
    fi
    echo "aria2c stopped and cleaned up."
}

# Trap exit to ensure cleanup
trap stop_symlink_script EXIT

# Monitor the Hydra launcher process
echo "Monitoring Hydra launcher process..."
while true; do
    if pgrep -f "/userdata/roms/ports/Hydra.sh" > /dev/null; then
        if [ -z "$SETUP_PID" ]; then
            start_symlink_script
        fi
    else
        if [ -n "$SETUP_PID" ]; then
            echo "Hydra launcher closed. Cleaning up aria2c..."
            stop_symlink_script
            SETUP_PID=""
            pkill -f hydra
        fi
    fi
    sleep 1
done
