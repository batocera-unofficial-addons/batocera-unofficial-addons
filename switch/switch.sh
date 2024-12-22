#!/bin/bash

# Get Batocera version
version=$(batocera-es-swissknife --version | awk '{print $1}' | sed 's/[^0-9]*//g')  # Extracts the numeric part

# Compare version and decide which download to trigger
if (( version == 39 || version == 40 )); then
    echo "Batocera version is 39 or 40. Triggering download for version 39/40..."
    wait 5
    curl -L bit.ly/foclabroc-switchoff-40 | bash
elif (( version >= 41 )); then
    echo "Batocera version is 41+. Triggering download for version 41+..."
    wait 5
    curl -L bit.ly/foclabroc-switchoff | bash
else
    echo "Unknown or unsupported Batocera version: $version"
fi
