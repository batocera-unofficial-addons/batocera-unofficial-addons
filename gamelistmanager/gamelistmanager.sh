#!/usr/bin/env bash
######################################################################
# GAMELIST-MANAGER INSTALLER
######################################################################
APPNAME="gamelist-manager"
appname="gamelist-manager"
AppName="gamelist-manager"
APPPATH=/userdata/system/add-ons/$appname
APPLINK=$(curl -s https://api.github.com/repos/RobG66/Gamelist-Manager/releases | grep "browser_download_url" | sed 's,^.*https://,https://,g' | cut -d \" -f1 | grep ".zip" | head -n1)
ORIGIN="github.com/RobG66/Gamelist-Manager"

# Output colors
X='\033[0m'
G='\033[0;32m'

# Prepare paths and files
add_ons_dir=/userdata/system/add-ons
mkdir -p $add_ons_dir/$appname/extra

# Download application
echo -e "${G}Downloading $APPNAME...${X}"
temp_dir=$add_ons_dir/$appname/extra/downloads
rm -rf $temp_dir && mkdir -p $temp_dir && cd $temp_dir
curl --progress-bar --remote-name --location "$APPLINK"
unzip -oq $PWD/*.zip -d $add_ons_dir/$appname
rm -rf $temp_dir

# Create launcher
launcher=$add_ons_dir/$appname/Launcher
cat <<EOF > $launcher
#!/bin/bash
export DISPLAY=:0.0
DISPLAY=:0.0 QT_SCALE_FACTOR="1.25" GDK_SCALE="1.25" batocera-wine windows play $add_ons_dir/$appname/Release/GamelistManager.exe
EOF
chmod a+x $launcher

# Create desktop shortcut
shortcut=$add_ons_dir/$appname/extra/$appname.desktop
cat <<EOF > $shortcut
[Desktop Entry]
Version=1.0
Icon=$add_ons_dir/$appname/extra/icon.png
Exec=$add_ons_dir/$appname/Launcher
Terminal=false
Type=Application
Categories=Game;
Name=$appname
EOF
chmod a+x $shortcut
cp $shortcut /usr/share/applications/ 2>/dev/null

# Add prelauncher to custom.sh
prelauncher=$add_ons_dir/$appname/extra/startup
cat <<EOF > $prelauncher
#!/usr/bin/env bash
cp $shortcut /usr/share/applications/ 2>/dev/null
EOF
chmod a+x $prelauncher

custom_sh=/userdata/system/custom.sh
if ! grep -q "$prelauncher" $custom_sh 2>/dev/null; then
  echo "$prelauncher" >> $custom_sh
fi
chmod a+x $custom_sh

echo -e "${G}> Installation complete. $APPNAME is ready!${X}"
