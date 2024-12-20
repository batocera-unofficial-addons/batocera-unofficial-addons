#!/usr/bin/env bash 
######################################################################
# BATOCERA-FIGHTCADE // FIGHTCADE BATOCERA INSTALLER
######################################################################
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#
# -- check system before proceeding
if [[ "$(uname -m)" != *"86_64"* ]]; then echo -e "\n\nFIGHTCADE2 NEEDS X86_64 CPU (INTEL/AMD), SORRY\n\n" && exit 1; fi
clear; echo
kernel=$(uname -a | awk '{print $3}' 2>/dev/null)
if [[ "$kernel" < "5.18" ]]; then 
echo -e "${RED}ERROR: THIS SYSTEM IS NOT SUPPORTED"
echo -e "${RED}YOU NEED BATOCERA VERSION 35+"
sleep 3
exit 0; exit 1; exit 2
fi 
free="$(df /userdata | awk 'END {print int($4/(1024*1024))}')"
if [[ "$free" -le "4" ]]; then 
echo -e "${RED}ERROR: YOU NEED AT LEAST 4GB OF FREE DISK SPACE ON /USERDATA "
echo -e "${RED}YOU HAVE $free GB"
sleep 3
exit 0; exit 1; exit 2
fi 
#
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#
spinner()
{
    local pid=$1
    local delay=0.2
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "PLEASE WAIT . . .  %c   " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    done
    printf "   \b\b\b\b"
}
#
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
# prepare paths and files for installation 
cd ~/
killall fc2-electron 2>/dev/null
fightcade=/userdata/system/add-ons/fightcade; mkdir -p $fightcade/extras 2>/dev/null
tmp=/tmp/batocera-fightcade; rm -rf $tmp 2>/dev/null; mkdir -p /tmp 2>/dev/null
# --------------------------------------------------------------------
# -- prepare dependencies for this app and the installer: 
url=https://raw.githubusercontent.com/DTJW92/batocera-unofficial-addons/main/fightcade/installer
wget -q -O $tmp/installer.sh $url/fightcade.sh 2>/dev/null 
dos2unix $tmp/installer.sh 2>/dev/null; chmod a+x $tmp/installer.sh 2>/dev/null
wget -q -O /tmp/libselinux.so.1 $url/libselinux.so.1 2>/dev/null 
wget -q -O /tmp/tar $url/tar 2>/dev/null; chmod a+x /tmp/tar 2>/dev/null
cp /tmp/libselinux.so.1 /lib/ 2>/dev/null
cp /tmp/tar /bin/tar 2>/dev/null
# --------------------------------------------------------------------
# show console info: 
clear
echo -e "--------------------------------------------------------"
echo -e "--------------------------------------------------------"
echo -e ""
echo -e "BATOCERA FIGHTCADE INSTALLER"
echo -e ""
echo -e "--------------------------------------------------------"
echo -e "--------------------------------------------------------"
echo
# --------------------------------------------------------------------
sleep 0.33
echo -e "THIS WILL INSTALL BATOCERA-FIGHTCADE"
echo -e "WITH ALL DEPENDENCIES FOR BATOCERA V36/37/38"
echo
echo -e "FIGHTCADE WILL BE AVAILABLE IN PORTS AND F1->APPLICATIONS "
echo -e "AND INSTALLED IN /userdata/system/add-ons/FIGHTCADE"
echo
sleep 3
echo
#
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
# -- download the package 
# -- set temp for curl download
dl=/userdata/system/add-ons/fightcade/extras/downloads
rm -rf $dl 2>/dev/null; mkdir $dl 2>/dev/null; cd $dl 
echo
echo -e "DOWNLOADING FIGHTCADE [1/9] . . ."
curl --progress-bar --remote-name --location https://github.com/DTJW92/batocera-unofficial-addons/raw/main/fightcade/package/fightcade.tar.gz

echo
echo -e "EXTRACTING. . . ."
cd /userdata/system/add-ons/
mv /userdata/system/add-ons/fightcade/extras/downloads/fightcade.tar.gz /userdata/system/add-ons/
chmod a+x /bin/tar 2>/dev/null
/bin/tar -xf /userdata/system/add-ons/fightcade.tar.gz 
rm -rf /userdata/system/add-ons/fightcade/extras/downloads 2>/dev/null
size=$(du -h ~/add-ons/fightcade | tail -n 1 | awk '{print $1}' | sed 's,G,,g')
echo -e "$size GB"
echo -e "DONE,"
#
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#
echo
echo -e "INSTALLING . . ."
#
# check d2u/a+x 
dos2unix /userdata/system/add-ons/fightcade/extras/startup.sh 2>/dev/null
dos2unix /userdata/system/add-ons/fightcade/extras/wine.sh 2>/dev/null
dos2unix /userdata/system/add-ons/fightcade/Fightcade2.sh 2>/dev/null
chmod a+x /userdata/system/add-ons/fightcade/extras/startup.sh 2>/dev/null
chmod a+x /userdata/system/add-ons/fightcade/extras/wine.sh 2>/dev/null
chmod a+x /userdata/system/add-ons/fightcade/Fightcade2.sh 2>/dev/null
/userdata/system/add-ons/fightcade/extras/startup.sh 2>/dev/null
# 
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
# 
# -------------------------------------------------------------------
# ADD TO BATOCERA AUTOSTART > /USERDATA/SYSTEM/CUSTOM.SH TO ENABLE F1
# -------------------------------------------------------------------
# 
csh=/userdata/system/custom.sh; dos2unix $csh 2>/dev/null
startup="/userdata/system/add-ons/fightcade/extras/startup.sh"
if [[ -f $csh ]];
   then
      tmp1=/tmp/tcsh1
      tmp2=/tmp/tcsh2
      remove="$startup"
      rm $tmp1 2>/dev/null; rm $tmp2 2>/dev/null
      nl=$(cat "$csh" | wc -l); nl1=$(($nl + 1))
         l=1; 
         for l in $(seq 1 $nl1); do
            ln=$(cat "$csh" | sed ""$l"q;d" );
               if [[ "$(echo "$ln" | grep "$remove")" != "" ]]; then :; 
                else 
                  if [[ "$l" = "1" ]]; then
                        if [[ "$(echo "$ln" | grep "#" | grep "/bin/" | grep "bash" )" != "" ]]; then :; else echo "$ln" >> "$tmp1"; fi
                     else 
                        echo "$ln" >> $tmp1;
                  fi
               fi            
            ((l++))
         done
         # 
         rm $tmp2 2>/dev/null
           echo -e '#!/bin/bash' >> $tmp2
           echo -e "\n$startup " >> $tmp2          
           cat "$tmp1" | sed -e '/./b' -e :n -e 'N;s/\n$//;tn' >> "$tmp2"
           cp $tmp2 $csh 2>/dev/null; dos2unix $csh 2>/dev/null; chmod a+x $csh 2>/dev/null  
   else  #(!f csh)   
       echo -e '#!/bin/bash' >> $csh
       echo -e "\n$startup\n" >> $csh  
       dos2unix $csh 2>/dev/null; chmod a+x $csh 2>/dev/null  
fi 
dos2unix ~/custom.sh 2>/dev/null
chmod a+x ~/custom.sh 2>/dev/null
# 
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
# 
# get updated files:
# --- 
url==https://github.com/DTJW92/batocera-unofficial-addons/raw/main/fightcade/installer
# startup 
wget -q -O /userdata/system/add-ons/fightcade/extras/startup.sh $url/startup.sh 2>/dev/null 
dos2unix /userdata/system/add-ons/fightcade/extras/startup.sh 1>/dev/null 2>/dev/null
chmod a+x /userdata/system/add-ons/fightcade/extras/startup.sh 2>/dev/null
# launcher 
wget -q -O /userdata/system/add-ons/fightcade/Fightcade2.sh $url/Fightcade2.sh 2>/dev/null 
dos2unix /userdata/system/add-ons/fightcade/Fightcade2.sh 1>/dev/null 2>/dev/null
chmod a+x /userdata/system/add-ons/fightcade/Fightcade2.sh 2>/dev/null
# winesync 
wget -q -O /userdata/system/add-ons/fightcade/extras/winesync.sh $url/winesync.sh 2>/dev/null 
dos2unix /userdata/system/add-ons/fightcade/extras/winesync.sh 1>/dev/null 2>/dev/null
chmod a+x /userdata/system/add-ons/fightcade/extras/winesync.sh 2>/dev/null
# syncwine 
wget -q -O /userdata/system/add-ons/fightcade/extras/syncwine.sh $url/syncwine.sh 2>/dev/null 
dos2unix /userdata/system/add-ons/fightcade/extras/syncwine.sh 1>/dev/null 2>/dev/null
chmod a+x /userdata/system/add-ons/fightcade/extras/syncwine.sh 2>/dev/null
# unwine 
wget -q -O /userdata/system/add-ons/fightcade/extras/unwine.sh $url/unwine.sh 2>/dev/null 
dos2unix /userdata/system/add-ons/fightcade/extras/unwine.sh 1>/dev/null 2>/dev/null
chmod a+x /userdata/system/add-ons/fightcade/extras/unwine.sh 2>/dev/null
# wine 
#wget -q -O /userdata/system/add-ons/fightcade/extras/wine.sh $url/wine.sh 2>/dev/null 
#dos2unix /userdata/system/add-ons/fightcade/extras/wine.sh 2>/dev/null
#chmod a+x /userdata/system/add-ons/fightcade/extras/wine.sh 2>/dev/null
# pad2key 
url==https://github.com/DTJW92/batocera-unofficial-addons/raw/main/fightcade/installer
wget -q -O /userdata/roms/ports/Fightcade2.sh.keys $url/Fightcade2.sh.keys 2>/dev/null 
# 
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#
# + additional updates/fixes for v37: 
url=https://github.com/DTJW92/batocera-unofficial-addons/raw/main/fightcade/installer
wget -q -O /userdata/system/add-ons/fightcade/extras/wine.sh $url/wine.sh 2>/dev/null
  dos2unix /userdata/system/add-ons/fightcade/extras/wine.sh 1>/dev/null 2>/dev/null 
  chmod a+x /userdata/system/add-ons/fightcade/extras/wine.sh 2>/dev/null 
wget -q -O /userdata/system/add-ons/fightcade/extras/liblua5.2.so.0 $url/liblua5.2.so.0 2>/dev/null 
wget -q -O /userdata/system/add-ons/fightcade/extras/liblua5.3.so.0 $url/liblua5.3.so.0 2>/dev/null 
wget -q -O /userdata/system/add-ons/fightcade/extras/libzip.so.4 $url/libzip.so.4 2>/dev/null 
wget -q -O /userdata/system/add-ons/fightcade/extras/libzip.so.5 $url/libzip.so.5 2>/dev/null 
# 
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#
# add Fightcade2 to ports
cp /userdata/system/add-ons/fightcade/Fightcade2.sh /userdata/roms/ports/Fightcade2.sh 2>/dev/null
# reload gamelists 
curl http://127.0.0.1:1234/reloadgames 
echo -e "DONE,"
# 
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
# 
# set icon for f1 launcher 
if [[ -f /userdata/system/add-ons/fightcade/extras/fightcade.desktop ]]; then 
    sed -i 's/icon.png/icong.png/g' /userdata/system/add-ons/fightcade/extras/fightcade.desktop 2>/dev/null
    /userdata/system/add-ons/fightcade/extras/startup.sh 2>/dev/null 
fi
# add --disable-gpu to fightcade launcher for compatibility  
if [[ -f /userdata/system/add-ons/fightcade/fightcade/Fightcade2.sh ]]; then
    if [[ $(cat "/userdata/system/add-ons/fightcade/fightcade/Fightcade2.sh" | grep "disable-gpu") = "" ]] || [[ $(cat "/userdata/system/add-ons/fightcade/fightcade/Fightcade2.sh" | grep "no-sandbox") != "" ]]; then
    sed -i 's/--no-sandbox/--no-sandbox --disable-gpu/g' /userdata/system/add-ons/fightcade/fightcade/Fightcade2.sh 2>/dev/null
    fi 
fi
# 
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#
# finished installing // 
echo 
echo 
echo -e "FIGHTCADE INSTALLED :) " 
echo 
# done
exit 0 
