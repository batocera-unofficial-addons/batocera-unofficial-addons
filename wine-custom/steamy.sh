#!/bin/bash

# Fetch aria2c
curl -L -o /userdata/system/add-ons/.dep/aria2c https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/wine-custom/extra/aria2c && chmod +x /userdata/system/add-ons/.dep/aria2c


# Create /userdata/system/wine/exe directory if it doesn't exist
mkdir -p /userdata/system/wine/exe

# Download steamy.exe with aria2c using 5 connections directly into /userdata/roms/wine/exe
./aria2c -x 5 -s 5 -d /userdata/system/wine/exe https://download2284.mediafire.com/njntbvzq57qgQs3G8R4u7McQKy0e3D7gXWicGQCF62zfy3zPQv4DYMGtbwDzM3owvOI7urBMTHbgU_AlGMg-U63JoqFwMMjLJ3HuAZcnxWf4ziPgbZL9BmJDqA1B6dPdfr9vOBAwrtbhEqI-_0lqCT6YrYwmSVyUISubAvOD17s/2w61oygu1o2k1mv/STEAMY-AiO.exe

# Check if the file was downloaded
if [ -f "/userdata/system/wine/exe/steamy.exe" ]; then
    echo "steamy.exe downloaded successfully."
else
    echo "Download failed or file not found."
fi

# Remove aria2c
rm aria2c

clear

# Output success message
echo "Steamy-AIO downloaded to /userdata/system/wine/exe."
echo ""
echo ""
echo "Rename /userdata/system/wine/exe.bak to /userdata/system/wine/exe anytime"
echo "you need to launch steamy-aio dependency installer before the windows game launches"
