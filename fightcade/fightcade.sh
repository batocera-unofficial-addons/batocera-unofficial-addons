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
curl -L https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/fightcade/lib/libs.zip -o /userdata/system/add-ons/$appname/lib/libs.zip
mkdir -p /userdata/system/add-ons/$appname/lib
unzip -o /userdata/system/add-ons/$appname/lib/libs.zip -d /userdata/system/add-ons/$appname/lib
rm /userdata/system/add-ons/$appname/lib/libs.zip

# -- Prepare launcher to solve dependencies on each run and avoid overlay
launcher="/userdata/system/add-ons/$appname/Launcher"
rm -rf $launcher
echo '#!/bin/bash ' >> $launcher
echo '~/add-ons/.dep/mousemove.sh 2>/dev/null' >> $launcher
## -- GET APP SPECIFIC LAUNCHER COMMAND:
######################################################################
echo "/userdata/system/add-ons/$appname/Fightcade2.sh" >> $launcher
######################################################################
dos2unix $launcher
chmod a+x $launcher
rm /userdata/system/add-ons/$appname/extra/command 2>/dev/null

# --------------------------------------------------------------------
# Get icon for Fightcade
extra=https://github.com/uureel/batocera.pro/raw/main/$appname/extra
echo "Downloading icon..."
wget --tries=10 --no-check-certificate --no-cache --no-cookies -q -O /userdata/system/add-ons/$appname/extra/icon.png $extra/icon.png

# --------------------------------------------------------------------
# -- Prepare F1 - applications - app shortcut
shortcut=/userdata/system/add-ons/$appname/extra/$appname.desktop
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
port="/userdata/roms/ports/$appname.sh"
rm "$port"
echo '#!/bin/bash ' >> $port
echo 'killall -9 Fightcade2.sh' >> $port  # Adjust this if needed
echo '/userdata/system/add-ons/'$appname'/Launcher' >> $port
dos2unix "$port"
chmod a+x "$port"

# --------------------------------------------------------------------
# -- Prepare prelauncher to avoid overlay
pre=/userdata/system/add-ons/$appname/extra/startup
rm -rf $pre 2>/dev/null
echo "#!/usr/bin/env bash" >> $pre
echo "cp /userdata/system/add-ons/$appname/extra/$appname.desktop /usr/share/applications/ 2>/dev/null" >> $pre
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

# -- Done!
echo "Fightcade installation and setup completed!"
