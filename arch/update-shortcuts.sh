#!/bin/bash

echo
echo "Updating shortcuts/launchers..."
echo
mkdir -p /userdata/roms/conty
github_url="https://raw.githubusercontent.com/DTJW92/batocera-unofficial-addons/main/arch/shortcuts/"

target_directory="/userdata/roms/conty/"
# List of .sh files to download
sh_files=(

"Boilr.sh"
"Bottles.sh"
"FileManager-PCManFM.sh"
"Filezilla.sh"
"Flatpak-Config.sh"
"Geforce Now.sh"
"Google-Chrome.sh"
"Greenlight.sh"
"Heroic Game Launcher.sh"
"Lutris.sh"
"Microsoft-Edge.sh"
"Moonlight.sh"
"Minecraft-Bedrock.sh"
# "OBS Studio.sh"
"Parsec.sh"
"Peazip.sh"
"Protonup-Qt.sh"
"Smplayer.sh"
"Spotify.sh"
"Steam Big Picture Mode.sh"
"Steam Diagnostic.sh"
"Steam.sh"
"SteamTinker Launch (settings).sh"
"Terminal-Tabby.sh"
"TigerVNC.sh"
"VLC.sh"
"WineGUI.sh"
)
# List of .sh files to remove
old_sh_files=(
  "Antimicrox.sh"
  "Audacity.sh"
  "Boilr.sh"
  "Brave.sh"
  "Firefox.sh"
  "GameHub.sh"
  "Geforce Now.sh"
  "Gimp.sh"
  "Google-Chrome.sh"
  "Gparted.sh"
  "Greenlight.sh"
  "Heroic Game Launcher.sh"
  "Inkscape.sh" 
  "Kdenlive.sh"
  "Kodi.sh"
  "Libreoffice.sh"
  "Lutris.sh"
  "Microsoft-Edge.sh"
  "Minigalaxy.sh"
  "Moonlight.sh"
  "OBS Studio.sh"
  "Opera.sh"
  "PCManFM (File Manager).sh"
  "Peazip.sh"
  "Play on Linux 4.sh"
  "Protonup-Qt.sh"
  "Qdirstat.sh"
  "Rustdesk.sh"
  "Smplayer.sh"
  "Shotcut.sh"
  "Steam Big Picture Mode.sh"
  "Steam.sh"
  "SteamTinker Launch (settings).sh"
  "Terminal.sh"
  "Thunderbird.sh"
  "VLC.sh"
  "Zoom.sh"
)
mkdir -p "$target_directory"
  # Remove old version .sh files
  for file in "${old_sh_files[@]}"; do
    rm "${target_directory}${file}" 2>/dev/null
  done
    for file in "${sh_files[@]}"; do
      # Replace spaces with '%20' for URL encoding
      encoded_file=$(echo "$file" | sed 's/ /%20/g')
      echo "Downloading $file..."
        wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O "${target_directory}${file}" "${github_url}${encoded_file}" &
      sleep 0.1
    done
      wait
        dos2unix "${target_directory}"/*.sh 2>/dev/null
          chmod 777 "${target_directory}"/*.sh 2>/dev/null

echo "Downloaded shortcuts."
echo
sleep 1


mkdir -p /userdata/system/configs/evmapy 2>/dev/null
rm /userdata/system/configs/emulationstation/es_features_steam2.cfg 2>/dev/null

echo "Downloading parsers and custom systems..."
  wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/roms/steam2/+UPDATE-STEAM-SHORTCUTS.sh https://github.com/trashbus99/batocera-unofficial-addons/raw/main/arch/shortcuts/%2BUPDATE-STEAM-SHORTCUTS.sh
  dos2unix /userdata/roms/steam2/+UPDATE-STEAM-SHORTCUTS.sh 2>/dev/null
  chmod 777 /userdata/roms/steam2/+UPDATE-STEAM-SHORTCUTS.sh 2>/dev/null

    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/emulationstation/es_systems_arch.cfg https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/es_systems_arch.cfg &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/emulationstation/es_features_arch.cfg https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/es_features_arch.cfg &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/emulationstation/es_systems_steam2.cfg https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/es_systems_steam2.cfg &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/emulationstation/es_features_steam2.cfg https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/es_features_steam2.cfg &
    #
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/Arch.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/Arch.keys &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/Lutris.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/Lutris.keys &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/Lutris.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/lutris.keys &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/Heroic2.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/Heroic2.keys &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/Heroic2.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/heroic2.keys &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/steam2.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/steam2.keys &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/steam.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/steam.keys &
    #
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/add-ons/arch/batocera-conty-patcher.sh https://github.com/trashbus99/profork/raw/master/steam/build/batocera-conty-patcher.sh &
        wait
            dos2unix /userdata/system/configs/emulationstation/*.cfg 2>/dev/null
            dos2unix /userdata/system/configs/evmapy/*.keys 2>/dev/null
            dos2unix /userdata/system/add-ons/arch/batocera-conty-patcher.sh 2>/dev/null
                chmod 777 /userdata/system/add-ons/arch/batocera-conty-patcher.sh 2>/dev/null

# lutris
if [[ -e /userdata/system/configs/emulationstation/es_systems_lutris.cfg ]]; then 
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/emulationstation/es_systems_lutris.cfg https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/es_systems_lutris.cfg &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/emulationstation/es_features_lutris.cfg https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/es_features_lutris.cfg &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/Lutris.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/Lutris.keys &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/Lutris.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/lutris.keys &
        wait
            dos2unix /userdata/system/configs/emulationstation/*.cfg 2>/dev/null
            dos2unix /userdata/system/configs/evmapy/*.keys 2>/dev/null
fi

# heroic
if [[ -e /userdata/system/configs/emulationstation/es_systems_heroic2.cfg ]]; then 
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/emulationstation/es_systems_heroic2.cfg https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/es_systems_heroic2.cfg &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/emulationstation/es_features_heroic2.cfg https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/es_features_heroic2.cfg &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/Heroic2.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/Heroic2.keys &
    wget -q --tries=50 --no-check-certificate --no-cache --no-cookies -O /userdata/system/configs/evmapy/Heroic2.keys https://github.com/trashbus99/profork/raw/master/steam/shortcuts/es_configs/keys/heroic2.keys &
        wait
            dos2unix /userdata/system/configs/emulationstation/*.cfg 2>/dev/null
            dos2unix /userdata/system/configs/evmapy/*.keys 2>/dev/null
fi 

rm /userdata/system/add-ons/arch/prepare.sh 2>/dev/null
dos2unix /userdata/roms/conty/*.sh 2>/dev/null
chmod 777 /userdata/roms/conty/*.sh 2>/dev/null

sleep 1
echo "Done."
sleep 1
