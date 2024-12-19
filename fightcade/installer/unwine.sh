#!/bin/bash
#
# wine-link / fightcade for batocera 
##################################################################################
##################################################################################
##################################################################################

# -- link wine software stack -- 
function batocera-fightcade-unwine() {
	
	rm /bin/grep 2>/dev/null
	rm /usr/bin/grep 2>/dev/null
	rm /usr/bin/xdg* 2>/dev/null
	rm /usr/bin/readlink 2>/dev/null
	rm /usr/bin/dirname 2>/dev/null
	rm /usr/bin/notify-send 2>/dev/null
	rm /usr/bin/zenity* 2>/dev/null

	rm /usr/i686-w64-mingw32 2>/dev/null
	rm /usr/x86_64-w64-mingw32 2>/dev/null

	rm /usr/lib/i386-linux-gnu 2>/dev/null
	rm /usr/lib/udev 2>/dev/null
	rm /usr/lib/wine 2>/dev/null
	rm /usr/lib/x86_64-linux-gnu 2>/dev/null

	rm /usr/share/zenity 2>/dev/null
	rm /usr/share/wine 2>/dev/null

	rm /usr/bin/i686-linux-gnu-pkg-config 2>/dev/null
	rm /usr/bin/msiexec 2>/dev/null
	rm /usr/bin/regedit 2>/dev/null
	rm /usr/bin/regsvr32 2>/dev/null
	rm /usr/bin/wine 2>/dev/null
	rm /usr/bin/wine64 2>/dev/null
	rm /usr/bin/wineboot 2>/dev/null
	rm /usr/bin/winecfg 2>/dev/null
	rm /usr/bin/wineconsole 2>/dev/null
	rm /usr/bin/winedbg 2>/dev/null
	rm /usr/bin/winefile 2>/dev/null
	rm /usr/bin/winepath 2>/dev/null
	rm /usr/bin/wineserver 2>/dev/null

	rm /usr/bin/wine-stable 2>/dev/null
	rm /usr/bin/wine 2>/dev/null
	rm /usr/bin/wine64-stable 2>/dev/null
	rm /usr/bin/wine64 2>/dev/null
	rm /usr/bin/wineboot-stable 2>/dev/null
	rm /usr/bin/wineboot 2>/dev/null
	rm /usr/bin/winecfg-stable 2>/dev/null
	rm /usr/bin/winecfg 2>/dev/null
	rm /usr/bin/wineconsole-stable 2>/dev/null
	rm /usr/bin/wineconsole 2>/dev/null
	rm /usr/bin/windbg-stable 2>/dev/null
	rm /usr/bin/windbg 2>/dev/null
	rm /usr/bin/winefile-stable 2>/dev/null
	rm /usr/bin/winefile 2>/dev/null
	rm /usr/bin/winepath-stable 2>/dev/null
	rm /usr/bin/winepath 2>/dev/null
	rm /usr/bin/winserver-stable 2>/dev/null
	rm /usr/bin/winserver 2>/dev/null

	rm /usr/bin/wine 2>/dev/null
	rm /usr/bin/wine64 2>/dev/null
	rm /usr/bin/wineboot 2>/dev/null
	rm /usr/bin/winecfg 2>/dev/null
	rm /usr/bin/wineconsole 2>/dev/null
	rm /usr/bin/windbg 2>/dev/null
	rm /usr/bin/winefile 2>/dev/null
	rm /usr/bin/winepath 2>/dev/null
	rm /usr/bin/winserver 2>/dev/null

	rm /lib/libunwind-coredump.so.0 2>/dev/null
	rm /lib/libunwind-coredump.so.0.0.0 2>/dev/null
	rm /lib/libunwind-ptrace.so.0 2>/dev/null
	rm /lib/libunwind-ptrace.so.0.0.0 2>/dev/null
	rm /lib/libunwind.so.8 2>/dev/null
	rm /lib/libunwind.so.8.0.1 2>/dev/null
	rm /lib/libunwind-x86_64.so.8 2>/dev/null
	rm /lib/libunwind-x86_64.so.8.0.1 2>/dev/null

	rm /lib/libpcre2-16.so.0 2>/dev/null
	rm /lib/libpcre2-16.so.0.9.0 2>/dev/null
	rm /lib/libpcre2-8.so.0 2>/dev/null
	rm /lib/libpcre2-8.so.0.9.0 2>/dev/null
	rm /lib/libpcreposix.so.3 2>/dev/null
	rm /lib/libpcreposix.so.3.13.3 2>/dev/null
	rm /lib/libpcre.so.3 2>/dev/null
	rm /lib/libpcre.so.3.13.3 2>/dev/null

	rm /usr/x86_64-linux-gnu 2>/dev/null
	rm /usr/i386-linux-gnu 2>/dev/null

	rm /lib32/ld-linux.so.2 2>/dev/null
	rm /usr/lib/i386-linux-gnu/ld-linux.so.2 2>/dev/null

		##################################
		# restore files from system backup
		b=/userdata/system/pro/fightcade/extras/system 
			cp -rL $b/grep /bin/ 2>/dev/null
			cp -rL $b/xdg* /usr/bin/ 2>/dev/null
			cp -rL $b/readlink /usr/bin/ 2>/dev/null
			cp -rL $b/dirname /usr/bin/ 2>/dev/null
			cp -rL $b/notify-send /usr/bin/ 2>/dev/null
			cp -rL $b/zenity* /usr/bin/ 2>/dev/null
			cp -r $b/libunwind* /lib/ 2>/dev/null
			cp -r $b/libpcre* /lib/ 2>/dev/null
			cp -r $b/ld-linux.so.2 /lib32/ 2>/dev/null
		# /restore
		##########

}
export -f batocera-fightcade-unwine 

##################################################################################
##################################################################################
##################################################################################

    echo
	echo -e "  # # #"
    echo -e "  #" 
    echo -e "  #   FIGHTCADE2 CLOSED, " 
    echo -e "  #   UNLINKING WINE ENVIRONMENT,"
	
		batocera-fightcade-unwine 2>/dev/null 

	echo -e "  #   DONE. "
    echo -e "  #" 
	echo -e "  # # #"
	echo
 
exit 0; exit 1; exit 2 
##################################################################################
##################################################################################
##################################################################################
