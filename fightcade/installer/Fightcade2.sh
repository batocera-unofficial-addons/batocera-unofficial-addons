#!/bin/bash
# BATOCERA-FIGHTCADE  
###########################################################################
# check if batocera is version 35+ 
kernel=$(uname -a | awk '{print $3}' 2>/dev/null)
if [[ "$kernel" < "5.18" ]]; then 
DISPLAY=:0.0 xterm -fs 10 -fullscreen -fg white -bg black -fa Monospace -en UTF-8 -e bash -c "echo -e \"  █\n  █  ERROR: FIGHTCADE REQUIRES BATOCERA VERSION 35+ \n  █\" & sleep 3" 2>/dev/null && exit 0 & exit 1 & exit 2
fi
###########################################################################
# make directory for fc1 roms 
mkdir -p /userdata/roms/fc1 2>/dev/null
# prepare winesync.sh 
dos2unix /userdata/system/pro/fightcade/extras/winesync.sh 2>/dev/null 
chmod a+x /userdata/system/pro/fightcade/extras/winesync.sh 2>/dev/null 
###########################################################################
# link rom folders for symlinking filesystems 
fs=$(blkid | grep "$(df -h /userdata | awk 'END {print $1}')" | sed 's,^.*TYPE=,,g' | sed 's,",,g' | tr 'a-z' 'A-Z')
#--------------------------------------------------------------------------
 if [[ "$fs" == *"EXT"* ]] || [[ "$fs" == *"BTR"* ]]; 
 then 
#--------------------------------------------------------------------------
#   0) show loading info 
    cp /usr/bin/xterm /usr/bin/loading_fightcade 2>/dev/null && chmod a+x /usr/bin/loading_fightcade 2>/dev/null
    DISPLAY=:0.0 /usr/bin/loading_fightcade -fs 8 -fullscreen -fg black -bg black -fa Monospace -en UTF-8 -e bash -c "echo -e \"\033[0;37mLOADING FIGHTCADE . . .\" & " 2>/dev/null & 
#--------------------------------------------------------------------------
#   1) link fightcade main ROMs folder 
    rm -rf /userdata/system/pro/fightcade/fightcade/ROMs/Flycast\ ROMs 2>/dev/null
    rm -rf /userdata/system/pro/fightcade/fightcade/ROMs/FBNeo\ ROMs 2>/dev/null
    rm -rf /userdata/system/pro/fightcade/fightcade/ROMs/SNES9x\ ROMs 2>/dev/null
    rm -rf /userdata/system/pro/fightcade/fightcade/ROMs/FC1\ ROMs 2>/dev/null
    mkdir -p /userdata/system/pro/fightcade/fightcade/ROMs 2>/dev/null
    ln -s /userdata/roms/dreamcast /userdata/system/pro/fightcade/fightcade/ROMs/Flycast\ ROMs 2>/dev/null
    ln -s /userdata/roms/fbneo /userdata/system/pro/fightcade/fightcade/ROMs/FBNeo\ ROMs 2>/dev/null
    ln -s /userdata/roms/snes /userdata/system/pro/fightcade/fightcade/ROMs/SNES9x\ ROMs 2>/dev/null
    ln -s /userdata/roms/fc1 /userdata/system/pro/fightcade/fightcade/ROMs/FC1\ ROMs 2>/dev/null
#--------------------------------------------------------------------------
#   2) link fightcade emulators ROMs folders 
    rm -rf /userdata/system/pro/fightcade/fightcade/emulator/flycast/ROMs 2>/dev/null
    rm -rf /userdata/system/pro/fightcade/fightcade/emulator/fbneo/ROMs 2>/dev/null
    rm -rf /userdata/system/pro/fightcade/fightcade/emulator/snes9x/ROMs 2>/dev/null
    rm -rf /userdata/system/pro/fightcade/fightcade/emulator/ggpofba/ROMs 2>/dev/null
    ln -s /userdata/roms/dreamcast /userdata/system/pro/fightcade/fightcade/emulator/flycast/ROMs 2>/dev/null
    ln -s /userdata/roms/fbneo /userdata/system/pro/fightcade/fightcade/emulator/fbneo/ROMs 2>/dev/null
    ln -s /userdata/roms/snes /userdata/system/pro/fightcade/fightcade/emulator/snes9x/ROMs 2>/dev/null
    ln -s /userdata/roms/fc1 /userdata/system/pro/fightcade/fightcade/emulator/ggpofba/ROMs 2>/dev/null
#--------------------------------------------------------------------------
#   3) link wine stack 
    dos2unix /userdata/system/pro/fightcade/extras/wine.sh 2>/dev/null 
    chmod a+x /userdata/system/pro/fightcade/extras/wine.sh 2>/dev/null 
    /userdata/system/pro/fightcade/extras/wine.sh 
#--------------------------------------------------------------------------
#   4) add libraries/dependencies 
    cp -rL /userdata/system/pro/fightcade/extras/libatk-bridge-2.0.so.0 /lib/ 2>/dev/null
    cp -rL /userdata/system/pro/fightcade/extras/libatspi.so.0 /lib/ 2>/dev/null
    cp -rL /userdata/system/pro/fightcade/extras/libcups.so.2 /lib/ 2>/dev/null
    cp -rL /userdata/system/pro/fightcade/wine/usr/bin/grep /bin/ 2>/dev/null
    cp -rL /userdata/system/pro/fightcade/wine/usr/bin/grep /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/pro/fightcade/wine/usr/bin/xdg* /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/pro/fightcade/wine/usr/bin/readlink /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/pro/fightcade/wine/usr/bin/dirname /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/pro/fightcade/wine/usr/bin/notify-send /usr/bin/ 2>/dev/null
    cp -rL /userdata/system/pro/fightcade/wine/usr/bin/zenity* /usr/bin/ 2>/dev/null
#--------------------------------------------------------------------------
#   5) start fightcade2 
    chmod a+x /userdata/system/pro/fightcade/fightcade/Fightcade2.sh 2>/dev/null
    unclutter-remote -s 
    echo 
    echo -e "  # # #"
    echo -e "  #    "
    echo -e "  #   STARTING FIGHTCADE $(cat /userdata/system/pro/fightcade/fightcade/VERSION.txt)"
    echo -e "  #    "
    echo -e "  # # #"
    /userdata/system/pro/fightcade/fightcade/Fightcade2.sh & 
    /userdata/system/pro/fightcade/extras/syncwine.sh & 
###########################################################################
else # display info that fightcade requires a symlinking filesystem & exit
DISPLAY=:0.0 xterm -fs 10 -fullscreen -fg white -bg black -fa Monospace -en UTF-8 -e bash -c "echo -e \"  █\n  █  ERROR: FIGHTCADE ON BATOCERA REQUIRES A SYMLINKING FILESYSTEM, EXT4 OR BTRFS \n  █\" & sleep 3" 2>/dev/null && exit 0 & exit 1 & exit 2
##-------------------------------------------------------------------------
fi 
