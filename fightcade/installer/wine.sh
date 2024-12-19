#!/bin/bash
#
# wine-link / fightcade for batocera 
##################################################################################
##################################################################################
##################################################################################

# -- link wine software stack -- 
function batocera-fightcade-wine() {
	
	cp -rL /userdata/system/pro/fightcade/wine/usr/bin/grep /bin/ 2>/dev/null
	cp -rL /userdata/system/pro/fightcade/wine/usr/bin/grep /usr/bin/ 2>/dev/null
	cp -rL /userdata/system/pro/fightcade/wine/usr/bin/xdg* /usr/bin/ 2>/dev/null
	cp -rL /userdata/system/pro/fightcade/wine/usr/bin/readlink /usr/bin/ 2>/dev/null
	cp -rL /userdata/system/pro/fightcade/wine/usr/bin/dirname /usr/bin/ 2>/dev/null
	cp -rL /userdata/system/pro/fightcade/wine/usr/bin/notify-send /usr/bin/ 2>/dev/null
	cp -rL /userdata/system/pro/fightcade/wine/usr/bin/zenity* /usr/bin/ 2>/dev/null

	ln -s /userdata/system/pro/fightcade/wine/usr/i686-w64-mingw32 /usr/i686-w64-mingw32 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/x86_64-w64-mingw32 /usr/x86_64-w64-mingw32 2>/dev/null

	ln -s /userdata/system/pro/fightcade/wine/usr/lib/i386-linux-gnu /usr/lib/i386-linux-gnu 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/lib/udev /usr/lib/udev 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/lib/wine /usr/lib/wine 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu 2>/dev/null

	ln -s /userdata/system/pro/fightcade/wine/usr/share/zenity /usr/share/zenity 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/share/wine /usr/share/wine 2>/dev/null

	ln -s /userdata/system/pro/fightcade/wine/usr/bin/i686-linux-gnu-pkg-config /usr/bin/i686-linux-gnu-pkg-config 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/msiexec /usr/bin/msiexec 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/regedit /usr/bin/regedit 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/regsvr32 /usr/bin/regsvr32 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wine /usr/bin/wine 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wine64 /usr/bin/wine64 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wineboot /usr/bin/wineboot 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winecfg /usr/bin/winecfg 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wineconsole /usr/bin/wineconsole 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winedbg /usr/bin/winedbg 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winefile /usr/bin/winefile 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winepath /usr/bin/winepath 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wineserver /usr/bin/wineserver 2>/dev/null

	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wine-stable /usr/bin/wine-stable 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wine-stable /usr/bin/wine 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wine64-stable /usr/bin/wine64-stable 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wine64-stable /usr/bin/wine64 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wineboot-stable /usr/bin/wineboot-stable 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wineboot-stable /usr/bin/wineboot 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winecfg-stable /usr/bin/winecfg-stable 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winecfg-stable /usr/bin/winecfg 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wineconsole-stable /usr/bin/wineconsole-stable 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wineconsole-stable /usr/bin/wineconsole 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winedbg-stable /usr/bin/windbg-stable 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winedbg-stable /usr/bin/windbg 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winefile-stable /usr/bin/winefile-stable 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winefile-stable /usr/bin/winefile 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winepath-stable /usr/bin/winepath-stable 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/winepath-stable /usr/bin/winepath 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wineserver-stable /usr/bin/winserver-stable 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/bin/wineserver-stable /usr/bin/winserver 2>/dev/null

	ln -sf /userdata/system/pro/fightcade/wine/usr/bin/wine-stable /usr/bin/wine 2>/dev/null
	ln -sf /userdata/system/pro/fightcade/wine/usr/bin/wine64-stable /usr/bin/wine64 2>/dev/null
	ln -sf /userdata/system/pro/fightcade/wine/usr/bin/wineboot-stable /usr/bin/wineboot 2>/dev/null
	ln -sf /userdata/system/pro/fightcade/wine/usr/bin/winecfg-stable /usr/bin/winecfg 2>/dev/null
	ln -sf /userdata/system/pro/fightcade/wine/usr/bin/wineconsole-stable /usr/bin/wineconsole 2>/dev/null
	ln -sf /userdata/system/pro/fightcade/wine/usr/bin/winedbg-stable /usr/bin/windbg 2>/dev/null
	ln -sf /userdata/system/pro/fightcade/wine/usr/bin/winefile-stable /usr/bin/winefile 2>/dev/null
	ln -sf /userdata/system/pro/fightcade/wine/usr/bin/winepath-stable /usr/bin/winepath 2>/dev/null
	ln -sf /userdata/system/pro/fightcade/wine/usr/bin/wineserver-stable /usr/bin/winserver 2>/dev/null

	cp -r /userdata/system/pro/fightcade/wine/usr/lib/x86_64-linux-gnu/libunwind* /lib/ 2>/dev/null
	cp -r /userdata/system/pro/fightcade/wine/usr/lib/x86_64-linux-gnu/libpcre* /lib/ 2>/dev/null

	ln -s /userdata/system/pro/fightcade/wine/usr/lib/x86_64-linux-gnu /usr/x86_64-linux-gnu 2>/dev/null
	ln -s /userdata/system/pro/fightcade/wine/usr/lib/i386-linux-gnu /usr/i386-linux-gnu 2>/dev/null

	cp -r /userdata/system/pro/fightcade/wine/usr/lib/i386-linux-gnu/ld-linux.so.2 /lib32/ld-linux.so.2 2>/dev/null
	cp -r /userdata/system/pro/fightcade/wine/usr/lib/i386-linux-gnu/ld-linux.so.2 /usr/lib/i386-linux-gnu/ld-linux.so.2 2>/dev/null

	# additional fixes for v37 
	ln -sf /userdata/system/pro/fightcade/extras/liblua5.2.so.0 /lib/liblua5.2.so.0 2>/dev/null 
	ln -sf /userdata/system/pro/fightcade/extras/liblua5.3.so.0 /lib/liblua5.3.so.0 2>/dev/null 
	ln -sf /userdata/system/pro/fightcade/extras/libzip.so.4 /lib/libzip.so.4 2>/dev/null 
	ln -sf /userdata/system/pro/fightcade/extras/libzip.so.5 /lib/libzip.so.5 2>/dev/null 
}
export -f batocera-fightcade-wine 

##################################################################################
##################################################################################
##################################################################################

    echo
	echo -e "  # # #"
    echo -e "  #" 
    echo -e "  #   STARTING WINE ENVIRONMENT FOR BATOCERA"
	
		batocera-fightcade-wine 2>/dev/null

	echo -e "  #   READY: $(/usr/bin/wine --version)"
    echo -e "  #" 
	echo -e "  # # #"
	echo
 
##################################################################################
##################################################################################
##################################################################################
