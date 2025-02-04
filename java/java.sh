#!/usr/bin/env bash 
#
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
#--------------------------------------------------------------------- 
#       DEFINE APP INFO >>
APPNAME=java
APPLINK=$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases | grep AppImage | grep "browser_download_url" | head -n 1 | sed 's,^.*https://,https://,g' | cut -d \" -f1) 2>/dev/null
APPHOME=azul.com/downloads
#---------------------------------------------------------------------
#       DEFINE LAUNCHER COMMAND >>
COMMAND='mkdir /userdata/system/add-ons/'$APPNAME'/home 2>/dev/null; mkdir /userdata/system/add-ons/'$APPNAME'/config 2>/dev/null; mkdir /userdata/system/add-ons/'$APPNAME'/roms 2>/dev/null; HOME=/userdata/system/add-ons/'$APPNAME'/home XDG_CONFIG_HOME=/userdata/system/add-ons/'$APPNAME'/config QT_SCALE_FACTOR="1" GDK_SCALE="1" XDG_DATA_HOME=/userdata/system/add-ons/'$APPNAME'/home DISPLAY=:0.0 /userdata/system/add-ons/'$APPNAME'/'$APPNAME'.AppImage --no-sandbox'
#--------------------------------------------------------------------- 
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
# --------------------------------------------------------------------
APPNAME="${APPNAME^^}"; ORIGIN="${APPHOME^^}"; appname=$(echo "$APPNAME" | awk '{print tolower($0)}'); AppName=$appname; APPPATH=/userdata/system/add-ons/$appname/$AppName.AppImage
# --------------------------------------------------------------------
# --------------------------------------------------------------------
# show console/ssh info: 
clear 
echo 
echo 
echo 
echo -e "${X}PREPARING $APPNAME INSTALLER, PLEASE WAIT . . . ${X}"
echo 
echo 
echo 
# --------------------------------------------------------------------
# -- output colors:
###########################
X='\033[0m'               # 
W='\033[0m'               # 
#-------------------------#
RED='\033[0m'             # 
BLUE='\033[0m'            # 
GREEN='\033[0m'           # 
PURPLE='\033[0m'          # 
DARKRED='\033[0m'         # 
DARKBLUE='\033[0m'        # 
DARKGREEN='\033[0m'       # 
DARKPURPLE='\033[0m'      # 
###########################
# --------------------------------------------------------------------
# -- console theme
L=$X
R=$X
# --------------------------------------------------------------------
# -- prepare paths and files for installation: 
cd ~/
pro=/userdata/system/add-ons
mkdir $pro 2>/dev/null
mkdir $pro/extra 2>/dev/null
rm -rf $pro/$appname 2>/dev/null
mkdir $pro/$appname 2>/dev/null
mkdir $pro/$appname/extra 2>/dev/null
# --------------------------------------------------------------------
# -- pass launcher command as cookie for main function: 
command=$pro/$appname/extra/command; rm $command 2>/dev/null;
echo "$COMMAND" >> $command 2>/dev/null 
# --------------------------------------------------------------------
wget -q -O $pro/$appname/extra/icon.png https://github.com/DRLEdition19/batocera-unofficial-addons.add/raw/main/$appname/extra/icon.png
# --------------------------------------------------------------------
# // end of dependencies 
#
# --------------------------------------------------------------------
# -- run before installer:  
#killall wget 2>/dev/null && killall $AppName 2>/dev/null && killall $AppName 2>/dev/null && killall $AppName 2>/dev/null
# --------------------------------------------------------------------
cols=$($dep/tput cols) 2>/dev/null; rm -rf /userdata/system/add-ons/$appname/extra/cols 2>/dev/null
echo $cols >> /userdata/system/add-ons/$appname/extra/cols 2>/dev/null
line(){
  local start=1
  local end=${1:-80}
  local str="${2:-=}"
  local range=$(seq $start $end)
  for i in $range ; do echo -n "${str}"; done
}
# -- show console/ssh info: 
clear
echo
echo
echo
echo -e "${X}/$APPNAME INSTALLER${X}"
echo
echo
echo
echo
sleep 0.33
clear
echo
echo
line $cols '-'; echo
echo -e "${X}/$APPNAME INSTALLER${X}"
line $cols '-'; echo
echo
echo
echo
sleep 0.33
clear
echo
line $cols '-'; echo
line $cols ' '; echo
echo -e "${X}/$APPNAME INSTALLER${X}"
line $cols ' '; echo
line $cols '-'; echo
echo
echo
sleep 0.33
clear
line $cols '\'; echo
line $cols '/'; echo
line $cols ' '; echo
echo -e "${X}/$APPNAME INSTALLER${X}"
line $cols ' '; echo
line $cols '/'; echo
line $cols '\'; echo
echo
sleep 0.33
echo -e "${X}THIS WILL INSTALL JAVA-RUNTIME 19.0.1 FOR BATOCERA"
echo -e "${X}USING $ORIGIN"
echo
echo -e "${X}$APPNAME WILL BE INSTALLED IN /USERDATA/SYSTEM/ADD-ONS/$APPNAME"
echo -e "${X}AND AVAILABLE AS A SYSTEM ADDON" 
echo
echo -e "${X}FOLLOW THE BATOCERA DISPLAY"
echo
echo -e "${X}. . .${X}" 
echo
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
# --------------------------------------------------------------------
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
# -- THIS WILL BE SHOWN ON MAIN BATOCERA DISPLAY:   
function batocera-installer {
APPNAME="$1"
appname="$2"
AppName="$3"
APPPATH="$4"
APPLINK="$5"
ORIGIN="$6"
# --------------------------------------------------------------------
# -- colors: 
###########################
X='\033[0m'               # 
W='\033[0m'               # 
#-------------------------#
RED='\033[0m'             # 
BLUE='\033[0m'            # 
GREEN='\033[0m'           # 
PURPLE='\033[0m'          # 
DARKRED='\033[0m'         # 
DARKBLUE='\033[0m'        # 
DARKGREEN='\033[0m'       # 
DARKPURPLE='\033[0m'      # 
###########################
# -- display theme:
L=$W
T=$W
R=$RED
B=$BLUE
G=$GREEN
P=$PURPLE
# --------------------------------------------------------------------
cols=$(cat /userdata/system/add-ons/.dep/display.cfg | tail -n 1) 2>/dev/null
cols=$(bc <<<"scale=0;$cols/1.3") 2>/dev/null
#cols=$(cat /userdata/system/add-ons/$appname/extra/cols | tail -n 1)
line(){
  local start=1
  local end=${1:-80}
  local str="${2:-=}"
  local range=$(seq $start $end)
  for i in $range ; do echo -n "${str}"; done
}
clear
echo
echo
echo
echo -e "${W}/${G}$APPNAME${W} INSTALLER ${W}"
echo
echo
echo
echo
sleep 0.33
clear
echo
echo
echo
echo -e "${W}/${W}$APPNAME${W} INSTALLER ${W}"
echo
echo
echo
echo
sleep 0.33
clear
echo
echo
line $cols '-'; echo
echo -e "${W}/${G}$APPNAME${W} INSTALLER ${W}"
line $cols '-'; echo
echo
echo
echo
sleep 0.33
clear
echo
line $cols '-'; echo
echo; #line $cols '-'; echo
echo -e "${W}/${W}$APPNAME${W} INSTALLER ${W}"
echo; #line $cols '-'; echo
line $cols '-'; echo
echo
echo
sleep 0.33
clear
line $cols '='; echo
echo; #line $cols '-'; echo
echo; #line $cols '-'; echo
echo -e "${W}/${G}$APPNAME${W} INSTALLER ${W}"
echo; #line $cols '-'; echo
echo; #line $cols '-'; echo
line $cols '='; echo
echo
sleep 0.33
echo -e "${W}THIS WILL INSTALL JAVA-RUNTIME 19.0.1 FOR BATOCERA"
echo -e "${W}USING $ORIGIN"
echo
echo -e "${W}$APPNAME WILL BE INSTALLED IN /USERDATA/SYSTEM/ADD-ONS/$APPNAME"
echo -e "${W}AND AVAILABLE AS A SYSTEM ADDON" 
echo
echo -e "${G}> > > ${W}PRESS ENTER TO CONTINUE"
read -p ""
echo; #line $cols '='; echo
# --------------------------------------------------------------------
# -- check system before proceeding
if [[ "$(uname -a | grep "x86_64")" != "" ]]; then 
:
else
echo
echo -e "${RED}ERROR: SYSTEM NOT SUPPORTED"
echo -e "${RED}YOU NEED BATOCERA X86_64${X}"
echo
sleep 5
exit 0
# quit
exit 0
fi
# --------------------------------------------------------------------
# -- temp for curl download
pro=/userdata/system/add-ons
temp=$pro/$appname/extra/downloads
rm -rf $temp 2>/dev/null 
mkdir -p $temp 2>/dev/null
# --------------------------------------------------------------------
echo
echo -e "${G}DOWNLOADING${W} JAVA-RUNTIME 19.0.1 PACKAGE [ 1+1 / 2 ] . . ."
url=https://github.com/DRLEdition19/batocera-unofficial-addons.add/raw/main/
p1=java.tar.bz2.partaa
p2=java.tar.bz2.partab
cd $temp
curl --progress-bar --remote-name --location "$url/$appname/extra/$p1"
curl --progress-bar --remote-name --location "$url/$appname/extra/$p2"
SIZE=$(du -sh $temp | awk '{print $1}') 2>/dev/null
echo -e "${T}$temp  ${T}$SIZE( )  ${G}OK${W}" | sed 's/( )//g' 2>/dev/null
echo
echo; #line $cols '='; echo
sleep 1.333 
# --------------------------------------------------------------------
echo -e "${G}INSTALLING${W} . . ." 
# --------------------------------------------------------------------
cat $temp/java.tar.bz2.parta* >$temp/java.tar.gz 2>/dev/null
cd ~/ 
SIZE=$(du -sh $pro/$appname | awk '{print $1}') 2>/dev/null
echo -e "${T}$pro/$appname  ${T}$SIZE( )  ${G}OK${W}" | sed 's/( )//g' 2>/dev/null
# --------------------------------------------------------------------
export='export PATH=/userdata/system/add-ons/java/bin:$PATH'
find="system/add-ons/java"
# --------------------------------------------------------------------
# attach java runtime to ~/.profile
file=/userdata/system/.profile
  if [[ -e "$file" ]]; then
temp=/userdata/system/.profile.tmp
rm $temp 2>/dev/null
nl=$(cat $file | wc -l)
l=1; while [[ $l -le $nl ]]; do
ln=$(cat $file | sed ""$l"q;d")
if [[ "$(echo $ln | grep "$find")" != "" ]]; then :; else echo "$ln" >> $temp; fi
((l++))
done
echo -e '\nexport PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java' >> $temp
cp $temp $file 2>/dev/null; rm $temp 2>/dev/null
  else
echo -e '\nexport PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java' >> $file
  fi
dos2unix /userdata/system/.profile 2>/dev/null
# --------------------------------------------------------------------
# attach java runtime to ~/.bashrc
file=/userdata/system/.bashrc
  if [[ -e "$file" ]]; then
temp=/userdata/system/.bashrc.tmp
rm $temp 2>/dev/null
nl=$(cat $file | wc -l)
l=1; while [[ $l -le $nl ]]; do
ln=$(cat $file | sed ""$l"q;d")
if [[ "$(echo $ln | grep "$find")" != "" ]]; then :; else echo "$ln" >> $temp; fi
((l++))
done
echo -e '\nexport PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java' >> $temp
cp $temp $file 2>/dev/null; rm $temp 2>/dev/null
  else
echo -e '\nexport PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java' >> $file
  fi
dos2unix /userdata/system/.bashrc 2>/dev/null
# --------------------------------------------------------------------
# run export: 
export PATH=/userdata/system/add-ons/java/bin:$PATH
export JAVA_HOME=/userdata/system/add-ons/java
# -- prepare launcher to solve dependencies on each run and avoid overlay, 
launcher=/userdata/system/add-ons/$appname/Launcher
rm -rf $launcher
echo '#!/bin/bash ' >> $launcher
echo 'export PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java' >> $launcher
echo 'function get-java-version {' >> $launcher
echo 'W="\033[0;37m" ' >> $launcher
echo 'java=/userdata/system/add-ons/java/bin/java' >> $launcher
echo 'if [[ -e "$java" ]]; then clear; echo -e "${W}JAVA RUNTIME AVAILABLE:"; echo; $java --version; sleep 4;' >> $launcher 
echo 'else clear; echo; echo -e "${W}JAVA RUNTIME NOT FOUND..."; echo; sleep 4; ' >> $launcher
echo 'fi' >> $launcher
echo '}' >> $launcher
echo 'export -f get-java-version 2>/dev/null' >> $launcher
echo 'function get-xterm-fontsize {' >> $launcher
echo 'tput=/userdata/system/add-ons/.dep/tput; chmod a+x $tput;' >> $launcher 
echo 'cp /userdata/system/add-ons/.dep/libtinfo.so.6 /lib/libtinfo.so.6 2>/dev/null' >> $launcher
echo 'cfg=/userdata/system/add-ons/.dep/display.cfg; rm $cfg 2>/dev/null' >> $launcher
echo 'DISPLAY=:0.0 xterm -fullscreen -bg "black" -fa "Monospace" -e bash -c "$tput cols >> $cfg" 2>/dev/null' >> $launcher
echo 'cols=$(cat $cfg | tail -n 1) 2>/dev/null' >> $launcher
echo 'TEXT_SIZE=$(bc <<<"scale=0;$cols/16") 2>/dev/null' >> $launcher
echo '}' >> $launcher
echo 'export -f get-xterm-fontsize 2>/dev/null' >> $launcher
echo 'get-xterm-fontsize 2>/dev/null' >> $launcher
echo 'cfg=/userdata/system/add-ons/.dep/display.cfg' >> $launcher
echo 'cols=$(cat $cfg | tail -n 1) 2>/dev/null' >> $launcher
echo 'until [[ "$cols" != "80" ]] ' >> $launcher
echo 'do' >> $launcher
echo 'get-xterm-fontsize 2>/dev/null' >> $launcher
echo 'cols=$(cat $cfg | tail -n 1) 2>/dev/null' >> $launcher
echo 'done ' >> $launcher
echo 'TEXT_SIZE=$(bc <<<"scale=0;$cols/16") 2>/dev/null' >> $launcher
echo 'DISPLAY=:0.0 xterm -fullscreen -bg black -fa 'Monospace' -fs $TEXT_SIZE -e bash -c "get-java-version" 2>/dev/null' >> $launcher
dos2unix $launcher 2>/dev/null
chmod a+x $launcher 2>/dev/null
rm /userdata/system/add-ons/$appname/extra/command 2>/dev/null
# --------------------------------------------------------------------
# -- prepare f1 - applications - app shortcut, 
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
dos2unix $shortcut 2>/dev/null
chmod a+x $shortcut 2>/dev/null
cp $shortcut $f1shortcut 2>/dev/null
# --------------------------------------------------------------------
# -- prepare prelauncher to avoid overlay,
pre=/userdata/system/add-ons/$appname/extra/startup
rm -rf $pre 2>/dev/null
echo "#!/usr/bin/env bash" >> $pre
echo "cp /userdata/system/add-ons/$appname/extra/$appname.desktop /usr/share/applications/ 2>/dev/null" >> $pre
echo "cp /userdata/system/add-ons/$appname/bin/java /usr/bin/java 2>/dev/null" >> $pre
dos2unix $pre 2>/dev/null
chmod a+x $pre 2>/dev/null
# -- add prelauncher to custom.sh to run @ reboot
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
dos2unix $csh 2>/dev/null
chmod a+x $csh 2>/dev/null
# -- done. 
sleep 1
echo -e "${G}> ${W}DONE${W}"
echo
sleep 1
echo
echo -e "${W}> $APPNAME INSTALLED ${G}OK${W}"
line $cols '='; echo
sleep 3
}
export -f batocera-installer 2>/dev/null
# --------------------------------------------------------------------
# RUN:
# |
  batocera-installer "$APPNAME" "$appname" "$AppName" "$APPPATH" "$APPLINK" "$ORIGIN"
# --------------------------------------------------------------------
clear
echo
echo -e "${W}> $APPNAME INSTALLED"
echo
