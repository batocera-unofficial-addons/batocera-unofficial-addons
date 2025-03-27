#!/bin/bash

# Check if rgs.version exists
if [ -f "/userdata/system/rgs.version" ]; then
    dialog --msgbox "Team Pixel Nostalgia's build supports Switch emulation natively. No need to install it via BUA." 8 60
    clear
    exit 0
fi

# Get Batocera version
version=$(batocera-es-swissknife --version | awk '{print $1}' | sed 's/[^0-9]*//g')  # Extracts the numeric part

# Compare version and decide which download to trigger
if (( version == 39 || version == 40 )); then
    echo "Batocera version is 39 or 40. Triggering download for version 39/40..."
    sleep 5
    curl -L bit.ly/foclabroc-switchoff-40 | bash
elif (( version == 41 )); then
    echo "Batocera version is 41. Triggering download for version 41..."
    sleep 5
 curl -L bit.ly/foclabroc-switchoff | bash
elif (( version >= 42 )); then
    echo "Batocera version is 42. Triggering download for version 42..."
    sleep 5
curl -L bit.ly/foclabroc-batswitch | bash
else
    echo "Unknown or unsupported Batocera version: $version"
    dialog --msgbox "Unsupported Batocera version detected: $version. Installation aborted." 8 60
    clear
fi
