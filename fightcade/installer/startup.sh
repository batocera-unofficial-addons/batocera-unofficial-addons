#!/bin/bash 
export DISPLAY=:0.0 

# backup system libraries/binaries 
rm -rf /userdata/system/pro/fightcade/extras/system 2>/dev/null
mkdir -p /userdata/system/pro/fightcade/extras/system 2>/dev/null
b=/userdata/system/pro/fightcade/extras/system 
	cp -rL /bin/grep $b/ 2>/dev/null
	cp -rL /usr/bin/xdg* $b/ 2>/dev/null
	cp -rL /usr/bin/readlink $b/ 2>/dev/null
	cp -rL /usr/bin/dirname $b/ 2>/dev/null
	cp -rL /usr/bin/notify-send $b/ 2>/dev/null
	cp -rL /usr/bin/zenity* $b/ 2>/dev/null
	cp -r /lib/libunwind* $b/ 2>/dev/null
	cp -r /lib/libpcre* $b/ 2>/dev/null
	cp -r /lib32/ld-linux.so.2 $b/ 2>/dev/null
	cp -r /usr/lib/i386-linux-gnu/ld-linux.so.2 $b/2>/dev/null
# /backup 

cp /userdata/system/pro/fightcade/extras/fightcade.desktop /usr/share/applications/ 2>/dev/null & 

