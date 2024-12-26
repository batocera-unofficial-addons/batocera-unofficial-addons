#!/bin/bash

# Define the app name for Fightcade
appname="fightcade"

# -- Download the latest Fightcade tar.gz and extract it into /userdata/system/add-ons/fightcade
echo "Downloading Fightcade..."
mkdir -p /userdata/system/add-ons/$appname
curl -L https://www.fightcade.com/download/linux -o /userdata/system/add-ons/$appname/fightcade-linux.tar.gz

echo "Extracting Fightcade..."
tar -xvf /userdata/system/add-ons/$appname/fightcade-linux.tar.gz -C /userdata/system/add-ons/$appname
rm /userdata/system/add-ons/$appname/fightcade-linux.tar.gz

# -- Download Fightcade dependencies and unzip them into /userdata/system/add-ons/fightcade/lib
echo "Downloading Fightcade dependencies..."
wget --tries=10 --no-check-certificate --no-cache --no-cookies -q -O /userdata/system/add-ons/fightcade/lib.zip  https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/fightcade/lib/lib.zip
unzip -oq /userdata/system/add-ons/fightcade/lib.zip -d /userdata/system/add-ons/fightcade
rm /userdata/system/add-ons/fightcade/lib.zip

# -- Prepare launcher to solve dependencies on each run and avoid overlay
launcher="/userdata/system/add-ons/$appname/Launcher"
rm -rf $launcher
echo '#!/bin/bash ' >> $launcher
echo '~/add-ons/.dep/mousemove.sh 2>/dev/null' >> $launcher
## -- GET APP SPECIFIC LAUNCHER COMMAND:
######################################################################
echo "/userdata/system/add-ons/$appname/Fightcade/Fightcade2.sh" >> $launcher
######################################################################
dos2unix $launcher
chmod a+x $launcher
rm /userdata/system/add-ons/$appname/extra/command 2>/dev/null

# --------------------------------------------------------------------
# Get icon for Fightcade
extra=https://github.com/DTJW92/batocera-unofficial-addons/raw/main/fightcade/extra/icon.png
echo "Downloading icon..."
wget --tries=10 --no-check-certificate --no-cache --no-cookies -q -O /userdata/system/add-ons/$appname/extra/icon.png $extra

# --------------------------------------------------------------------
# -- Prepare F1 - applications - app shortcut
shortcut=/userdata/system/add-ons/fightcade/Fightcade/Fightcade.desktop
rm -rf $shortcut 2>/dev/null
echo "[Desktop Entry]" >> $shortcut
echo "Version=1.0" >> $shortcut
echo "Icon=/userdata/system/add-ons/$appname/extra/icon.png" >> $shortcut
echo "Exec=/userdata/system/add-ons/$appname/Launcher" >> $shortcut
echo "Terminal=false" >> $shortcut
echo "Type=Application" >> $shortcut
echo "Categories=Game;batocera.linux;" >> $shortcut
echo "Name=$appname" >> $shortcut
f1shortcut=/usr/share/applications/$appname.desktop
dos2unix $shortcut
chmod a+x $shortcut
cp $shortcut $f1shortcut 2>/dev/null

# --------------------------------------------------------------------
# -- Prepare Ports file
port="/userdata/roms/ports/Fightcade2.sh"
rm "$port"
cat << 'EOF' > /userdata/roms/ports/Fightcade2.sh
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
#   start fightcade2 
    chmod a+x /userdata/system/add-ons/fightcade/fightcade/Fightcade2.sh 2>/dev/null
    unclutter-remote -s 
    echo 
    echo -e "  # # #"
    echo -e "  #    "
    echo -e "  #   STARTING FIGHTCADE $(cat /userdata/system/add-ons/fightcade/Fightcade/VERSION.txt)"
    echo -e "  #    "
    echo -e "  # # #"
    /userdata/system/pro/fightcade/fightcade/Fightcade2.sh & 
    /userdata/system/pro/fightcade/extras/syncwine.sh & 
########################################################################### '
EOF

dos2unix "$port"
chmod a+x "$port"

# --------------------------------------------------------------------
# -- Prepare prelauncher to avoid overlay
pre=/userdata/system/add-ons/$appname/extra/startup
mkdir -p $pre
rm -rf $pre 2>/dev/null
echo "#!/usr/bin/env bash" >> $pre
echo "cp /userdata/system/add-ons/$appname/extra/Fightcade.desktop /usr/share/applications/ 2>/dev/null" >> $pre
dos2unix $pre
chmod a+x $pre

# -- Add prelauncher to custom.sh to run @ reboot
csh=/userdata/system/custom.sh
if [[ -e $csh ]] && [[ "$(cat $csh | grep "/userdata/system/add-ons/$appname/extra/startup")" = "" ]]; then
    echo -e "\n/userdata/system/add-ons/$appname/extra/startup" >> $csh
fi
if [[ -e $csh ]] && [[ "$(cat $csh | grep "/userdata/system/add-ons/$appname/extra/startup" | grep "#")" != "" ]]; then
    echo -e "\n/userdata/system/add-ons/$appname/extra/startup" >> $csh
fi
if [[ -e $csh ]]; then :; else
    echo -e "\n/userdata/system/add-ons/$appname/extra/startup" >> $csh
fi
dos2unix $csh

# --------------------------------------------------------------------
# 1) Link Fightcade main ROMs folder
echo "Linking Fightcade ROMs folders..."
rm -rf /userdata/system/add-ons/fightcade/Fightcade/ROMs/Flycast\ ROMs 2>/dev/null
rm -rf /userdata/system/add-ons/fightcade/Fightcade/ROMs/FBNeo\ ROMs 2>/dev/null
rm -rf /userdata/system/add-ons/fightcade/Fightcade/ROMs/SNES9x\ ROMs 2>/dev/null
rm -rf /userdata/system/add-ons/fightcade/Fightcade/ROMs/FC1\ ROMs 2>/dev/null
mkdir -p /userdata/system/add-ons/fightcade/Fightcade/ROMs 2>/dev/null
ln -s /userdata/roms/dreamcast /userdata/system/add-ons/fightcade/Fightcade/ROMs/Flycast\ ROMs 2>/dev/null
ln -s /userdata/roms/fbneo /userdata/system/add-ons/fightcade/Fightcade/ROMs/FBNeo\ ROMs 2>/dev/null
ln -s /userdata/roms/snes /userdata/system/add-ons/fightcade/Fightcade/ROMs/SNES9x\ ROMs 2>/dev/null
ln -s /userdata/roms/fc1 /userdata/system/add-ons/fightcade/Fightcade/ROMs/FC1\ ROMs 2>/dev/null

# --------------------------------------------------------------------
# 2) Link Fightcade emulators ROMs folders
echo "Linking Fightcade emulator ROMs folders..."
rm -rf /userdata/system/add-ons/fightcade/Fightcade/emulator/flycast/ROMs 2>/dev/null
rm -rf /userdata/system/add-ons/fightcade/Fightcade/emulator/fbneo/ROMs 2>/dev/null
rm -rf /userdata/system/add-ons/fightcade/Fightcade/emulator/snes9x/ROMs 2>/dev/null
rm -rf /userdata/system/add-ons/fightcade/Fightcade/emulator/ggpofba/ROMs 2>/dev/null
ln -s /userdata/roms/dreamcast /userdata/system/add-ons/fightcade/Fightcade/emulator/flycast/ROMs 2>/dev/null
ln -s /userdata/roms/fbneo /userdata/system/add-ons/fightcade/Fightcade/emulator/fbneo/ROMs 2>/dev/null
ln -s /userdata/roms/snes /userdata/system/add-ons/fightcade/Fightcade/emulator/snes9x/ROMs 2>/dev/null
ln -s /userdata/roms/fc1 /userdata/system/add-ons/fightcade/Fightcade/emulator/ggpofba/ROMs 2>/dev/null


curl -L https://fightcade.download/fc2json.zip -o /userdata/system/add-ons/fightcade/Fightcade/fc2json.zip
unzip -o /userdata/system/add-ons/fightcade/Fightcade/fc2json.zip -d /userdata/system/add-ons/fightcade/Fightcade/emulator
rm /userdata/system/add-ons/fightcade/Fightcade/fc2json.zip

curl -o /userdata/system/add-ons/fightcade/extra/wine.sh https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/fightcade/wine.sh
curl -o /userdata/system/add-ons/fightcade/extra/syncwine.sh https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/fightcade/syncwine.sh
curl -o /userdata/system/add-ons/fightcade/extra/unwine.sh https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/fightcade/unwine.sh
chmod +x /userdata/system/add-ons/fightcade/extra/wine.sh
chmod +x /userdata/system/add-ons/fightcade/extra/unwine.sh
chmod +x /userdata/system/add-ons/fightcade/extra/syncwine.sh

echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# -- Done!
echo "Fightcade installation, setup, and linking completed!"
