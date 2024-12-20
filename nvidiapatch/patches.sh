#!/bin/bash
# // batocera-sunshine nvidia-patcher // 
# this will auto download full nvidia drivers run package, extract some files, patch some files, store 
# the patched stuff in userdata, so that batocera-sunshine can use hardware acceleration on nvidia gpus. 
# --------------------------------------------------------------------------------------------------------
echo -e "##  "
echo -e "##  starting batocera-sunshine nvidia-patcher, please wait . . . "
echo -e "##  "
echo 
echo -e "##  "
echo -e "##  NOTE: "
echo -e "##  if this process gets interrupted or errors out,  "
echo -e "##  remove /userdata/system/add-ons/sunshine/nvidia and start again "
echo -e "##  "
echo 
# --------------------------------------------------------------------------------------------------------
version="$1"
patch_status="maybe"
fbcpatch_status="maybe"
mkdir -p /opt/nvidia 2>/dev/null 
cookie=/tmp/patchstatus_ok ; rm $cookie 2>/dev/null
tmp=/userdata/system/add-ons/sunshine/nvidia/tmp ; rm -rf "$tmp" 2>/dev/null ; mkdir -p "$tmp" 2>/dev/null
nvdir=/userdata/system/add-ons/sunshine/nvidia/$version ; rm -rf "$nvdir" 2>/dev/null ; mkdir -p "$nvdir" 2>/dev/null 
# --------------------------------------------------------------------------------------------------------
echo -e "##  "
echo -e "##  downloading nvidia drivers version: $version "
echo -e "##  "
link=https://us.download.nvidia.com/XFree86/Linux-x86_64/$version/NVIDIA-Linux-x86_64-$version.run 
# Prepare to patch files 
cd "$tmp"
	runfile="$tmp/nvidia-drivers-$version.run"
		# Download drivers package 
		curl -o "$runfile" --progress-bar "$link"
		chmod 777 "$runfile"
		# Extract it
		"$runfile" --extract-only --target "$tmp/$version"
			# Copy needed files
			cp $tmp/$version/libcuda* $nvdir/
			cp $tmp/$version/libnvcuvid* $nvdir/
			cp $tmp/$version/libvdpau_nvidia* $nvdir/
			#
			# Prepare to patch fbc and encode libraries
			cp $tmp/$version/libnvidia-encode* /usr/lib/
			cp $tmp/$version/libnvidia-fbc* /usr/lib/
			cp $tmp/$version/nvidia-smi /usr/bin/
			chmod 777 /usr/bin/nvidia-smi 2>/dev/null
			#
			# add nvidia-smi and nvidia-settings
			cp $tmp/$version/nvidia-smi $nvdir/ 2>/dev/null
			cp $tmp/$version/nvidia-settings $nvdir/ 2>/dev/null
			cp $tmp/$version/libnvidia-gtk* $nvdir/
			chmod 777 $nvdir/nvidia-smi 2>/dev/null
			chmod 777 $nvdir/nvidia-settings 2>/dev/null
				#
				# But first try update nvidia patchers 
				#
				# patch.sh
				nvpatch_file=/userdata/system/add-ons/sunshine/nvidia/batocera-sunshine-nvidia-patch.sh
				nvpatch_tmpfile=/userdata/system/add-ons/sunshine/nvidia/tmp/batocera-sunshine-nvidia-patch.sh
				nvpatch_link=https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh
				# patch-fbc.sh
				nvfbcpatch_file=/userdata/system/add-ons/sunshine/nvidia/batocera-sunshine-nvidia-fbcpatch.sh
				nvfbcpatch_tmpfile=/userdata/system/add-ons/sunshine/nvidia/tmp/batocera-sunshine-nvidia-fbcpatch.sh
				nvfbcpatch_link=https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch-fbc.sh
					curl -o "$nvpatch_tmpfile" --progress-bar "$nvpatch_link"
					curl -o "$nvfbcpatch_tmpfile" --progress-bar "$nvfbcpatch_link"
						# Check/update patchers 
						# patch.sh 
							if [[ "$(wc -c "$nvpatch_tmpfile" | awk '{print $1}')" < "10000" ]]; then 
								# download failed? trying bundled version 
								echo
								echo -e "##   "
								echo -e "##   patch.sh  :  warning, script update/download failed, will try the bundled version..."
								echo -e "##   "
								echo
									chmod 777 "$nvpatch_file" 2>/dev/null
									dos2unix "$nvpatch_file" 2>/dev/null
							else
									chmod 777 "$nvpatch_tmpfile" 2>/dev/null
									dos2unix "$nvpatch_tmpfile" 2>/dev/null
									cp "$nvpatch_tmpfile" "$nvpatch_file"
							fi
						# fbc-patch.sh 
							if [[ "$(wc -c "$nvfbcpatch_tmpfile" | awk '{print $1}')" < "10000" ]]; then 
								# download failed? trying bundled version 
								echo
								echo -e "##   "
								echo -e "##   fbc-patch.sh  :  warning, script update/download failed, will try the bundled version..."
								echo -e "##   "
								echo
									chmod 777 "$nvfbcpatch_file" 2>/dev/null
									dos2unix "$nvfbcpatch_file" 2>/dev/null
							else
									chmod 777 "$nvfbcpatch_tmpfile" 2>/dev/null
									dos2unix "$nvfbcpatch_tmpfile" 2>/dev/null
									cp "$nvfbcpatch_tmpfile" "$nvfbcpatch_file"
							fi							
						# Check compatibility 
							# patch.sh 
								if [[ "$(cat "$nvpatch_file" | grep "$version")" = "" ]]; then 
									echo
									echo -e "##   "
									echo -e "##   patch.sh  :  can't run ;( ... "
									echo -e "##   patch.sh  :  does NOT support version $version ... yet?"
									echo -e "##   "
									echo
								else
									echo
									echo -e "##   "
									echo -e "##   patch.sh  :  patching libnvidia-encode $version "
									echo -e "##   "
									echo
									####
									#### RUN PATCHER 
									####
									bash "$nvpatch_file" 2>/dev/null
										cp /usr/lib/libnvidia-encode* $nvdir/
										patch_status="ok"
								fi
							# fbc-patch.sh

								if [[ "$(cat "$nvfbcpatch_file" | grep "$version")" = "" ]]; then 
									echo
									echo -e "##   "
									echo -e "##   fbc-patch.sh  :  can't run ;( ... "
									echo -e "##   fbc-patch.sh  :  does NOT support version $version ... yet?"
									echo -e "##   "
									echo
								else
									echo
									echo -e "##   "
									echo -e "##   fbc-patch.sh  :  patching libnvidia-fbc $version "
									echo -e "##   "
									echo
									####
									#### RUN PATCHER 
									####
									bash "$nvfbcpatch_file" 2>/dev/null
										cp /usr/lib/libnvidia-fbc* $nvdir/
										fbcpatch_status="ok"
								fi
# Clear rmp 
rm -rf "$tmp" 2>/dev/null
# --------------------------------------------------------------------------------------------------------
if [[ "$patch_status" = "ok" ]] && [[ "$fbcpatch_status" = "ok" ]]; then 
	echo
	echo -e "##   "
	echo -e "##   OK! :) "
	echo -e "##   Looks like everything went well, hopefully ;) ... "
	echo -e "##   "
	echo
	cookie=/tmp/patchstatus_ok ; rm $cookie 2>/dev/null
	touch $cookie
	exit 0
else 
	echo
	echo -e "##   "
	echo -e "##   Oops :( "
	echo -e "##   Drivers were not patched correctly"
	echo -e "##   Sunshine hardware acceleration probably won't work "
	echo -e "##   "
	echo
	exit 1
fi
# --------------------------------------------------------------------------------------------------------
exit 0
