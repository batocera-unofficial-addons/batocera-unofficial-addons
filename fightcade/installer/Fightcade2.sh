#!/bin/bash
# BATOCERA-FIGHTCADE  
###########################################################################
# Log file setup
log_dir="/userdata/system/logs"
log_file="${log_dir}/fightcade.log"
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Starting Fightcade setup"

###########################################################################
# Check if Batocera is version 35+
kernel=$(uname -a | awk '{print $3}' 2>/dev/null)
if [[ "$kernel" < "5.18" ]]; then 
    echo "$(date): ERROR: FIGHTCADE REQUIRES BATOCERA VERSION 35+" 
    DISPLAY=:0.0 xterm -fs 10 -fullscreen -fg white -bg black -fa Monospace -en UTF-8 -e bash -c "echo -e \"  █\n  █  ERROR: FIGHTCADE REQUIRES BATOCERA VERSION 35+ \n  █\" & sleep 3" 2>/dev/null && exit 0 & exit 1 & exit 2
fi
###########################################################################
# Make directory for fc1 roms
mkdir -p /userdata/roms/fc1 2>/dev/null
echo "$(date): Created /userdata/roms/fc1 directory"

# Prepare winesync.sh 
dos2unix /userdata/system/add-ons/fightcade/extras/winesync.sh 2>/dev/null
chmod a+x /userdata/system/add-ons/fightcade/extras/winesync.sh 2>/dev/null 
echo "$(date): Prepared winesync.sh script"

###########################################################################
# Link rom folders for symlinking filesystems 
fs=$(blkid | grep "$(df -h /userdata | awk 'END {print $1}')" | sed 's,^.*TYPE=,,g' | sed 's,",,g' | tr 'a-z' 'A-Z')

if [[ "$fs" == *"EXT"* ]] || [[ "$fs" == *"BTR"* ]]; then 
    # Show loading info
    cp /usr/bin/xterm /usr/bin/loading_fightcade 2>/dev/null && chmod a+x /usr/bin/loading_fightcade 2>/dev/null
    DISPLAY=:0.0 /usr/bin/loading_fightcade -fs 8 -fullscreen -fg black -bg black -fa Monospace -en UTF-8 -e bash -c "echo -e \"\033[0;37mLOADING FIGHTCADE . . .\" & " 2>/dev/null & 
    echo "$(date): Showing loading screen"

    # Link fightcade main ROMs folder 
    rm -rf /userdata/system/add-ons/fightcade/ROMs/Flycast\ ROMs 2>/dev/null
    rm -rf /userdata/system/add-ons/fightcade/ROMs/FBNeo\ ROMs 2>/dev/null
    rm -rf /userdata/system/add-ons/fightcade/ROMs/SNES9x\ ROMs 2>/dev/null
    rm -rf /userdata/system/add-ons/fightcade/ROMs/FC1\ ROMs 2>/dev/null
    mkdir -p /userdata/system/add-ons/fightcade/ROMs 2>/dev/null
    ln -s /userdata/roms/dreamcast /userdata/system/add-ons/fightcade/ROMs/Flycast\ ROMs 2>/dev/null
    ln -s /userdata/roms/fbneo /userdata/system/add-ons/fightcade/ROMs/FBNeo\ ROMs 2>/dev/null
    ln -s /userdata/roms/snes /userdata/system/add-ons/fightcade/ROMs/SNES9x\ ROMs 2>/dev/null
    ln -s /userdata/roms/fc1 /userdata/system/add-ons/fightcade/ROMs/FC1\ ROMs 2>/dev/null
    echo "$(date): Linked main ROM folders"

    # Link fightcade emulators ROMs folders 
    rm -rf /userdata/system/add-ons/fightcade/emulator/flycast/ROMs 2>/dev/null
    rm -rf /userdata/system/add-ons/fightcade/emulator/fbneo/ROMs 2>/dev/null
    rm -rf /userdata/system/add-ons/fightcade/emulator/snes9x/ROMs 2>/dev/null
    rm -rf /userdata/system/add-ons/fightcade/emulator/ggpofba/ROMs 2>/dev/null
    ln -s /userdata/roms/dreamcast /userdata/system/add-ons/fightcade/emulator/flycast/ROMs 2>/dev/null
    ln -s /userdata/roms/fbneo /userdata/system/add-ons/fightcade/emulator/fbneo/ROMs 2>/dev/null
    ln -s /userdata/roms/snes /userdata/system/add-ons/fightcade/emulator/snes9x/ROMs 2>/dev/null
    ln -s /userdata/roms/fc1 /userdata/system/add-ons/fightcade/emulator/ggpofba/ROMs 2>/dev/null
    echo "$(date): Linked emulator ROMs folders"

    # Link wine stack
    dos2unix /userdata/system/add-ons/fightcade/extras/wine.sh 2>/dev/null 
    chmod a+x /userdata/system/add-ons/fightcade/extras/wine.sh 2>/dev/null 
    cd /userdata/system/add-ons/fightcade/extras
    ./wine.sh
    echo "$(date): Executed wine.sh script"

    # Add libraries/dependencies 
    cp -rL /userdata/system/add-ons/fightcade/extras/libatk-bridge-2.0.so.0 /lib/ 2>/dev/null
    cp -rL /userdata/system/add-ons/fightcade/extras/libatspi.so.0 /lib/ 2>/dev/null
    cp -rL /userdata/system/add-ons/fightcade/extras/libcups.so.2 /lib/ 2>/dev/null
    cp -rL /userdata/system/add-ons/fightcade/wine/usr/bin/grep /bin/ 2>/dev/null
    cp -rL /userdata/system/add-ons/fightcade/wine/usr/bin/grep /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/add-ons/fightcade/wine/usr/bin/xdg* /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/add-ons/fightcade/wine/usr/bin/readlink /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/add-ons/fightcade/wine/usr/bin/dirname /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/add-ons/fightcade/wine/usr/bin/notify-send /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/add-ons/fightcade/wine/usr/bin/zenity* /usr/bin/ 2>/dev/null
    echo "$(date): Copied libraries and dependencies"

    # Start Fightcade2 
    chmod a+x /userdata/system/add-ons/fightcade/Fightcade2.sh 2>/dev/null
    unclutter-remote -s 
    echo "$(date): Starting Fightcade $(cat /userdata/system/add-ons/fightcade/VERSION.txt)"
    /userdata/system/add-ons/fightcade/Fightcade2.sh & 
    /userdata/system/add-ons/fightcade/extras/syncwine.sh & 
    echo "$(date): Fightcade2 started"

else
    # Display info that Fightcade requires a symlinking filesystem & exit
    echo "$(date): ERROR: FIGHTCADE REQUIRES A SYMLINKING FILESYSTEM, EXT4 OR BTRFS"
    DISPLAY=:0.0 xterm -fs 10 -fullscreen -fg white -bg black -fa Monospace -en UTF-8 -e bash -c "echo -e \"  █\n  █  ERROR: FIGHTCADE REQUIRES A SYMLINKING FILESYSTEM, EXT4 OR BTRFS \n  █\" & sleep 3" 2>/dev/null && exit 0 & exit 1 & exit 2
fi
