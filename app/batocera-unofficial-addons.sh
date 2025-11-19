#!/bin/bash

LAUNCH_PATH="/userdata/roms/ports/bua.sh"
SYMLINK_MANAGER_PATH="/userdata/system/services/symlink_manager"

install_bua() {
    curl -L install.batoaddons.app | bash
}

grep -q '^Exec=/userdata/roms/ports/BatoceraUnofficialAddOns.sh' /usr/share/applications/BUA.desktop && { rm -f /usr/share/applications/BUA.desktop >/dev/null 2>&1; /userdata/system/configs/bua/restore_desktop_entry.sh >/dev/null 2>&1; }


if [ ! -e "$SYMLINK_MANAGER_PATH" ]; then
    install_bua
    dialog --title "Reinstallation Required" --msgbox \
        "You've ran RGS install script since installing BUA! BUA has reinstalled, but previous application installs will need to be installed again." 10 60
fi

if grep -q 'DTJW92' "$LAUNCH_PATH"; then
    install_bua
fi

# Function to display animated title with colors
animate_title() {
    local text="BATOCERA UNOFFICIAL ADD-ONS INSTALLER"
    local delay=0.01
    local length=${#text}

    echo -ne "\e[1;36m"  # Set color to cyan
    for (( i=0; i<length; i++ )); do
        echo -n "${text:i:1}"
        sleep $delay
    done
    echo -e "\e[0m"  # Reset color
}

# Function to display animated border
animate_border() {
    local char="#"
    local width=50

    for (( i=0; i<width; i++ )); do
        echo -n "$char"
        sleep 0.01
    done
    echo -e
}

# Function to display controls
display_controls() {
# Display the ASCII art
echo -e "\e[1;90m"
echo -e "                                                             \e[1;90m ⠈⠻⠷⠄     \e[0m                 "
echo -e "                                                      \e[1;90m ⣀⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣀  \e[0m   "
echo -e "                                                    \e[1;90m ⣰⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⣿⣿⣿⣆ \e[0m  "
echo -e "\e[31m  ____        _          \e[0m                           \e[1;90m⢰⣿⣿⠟⠛⠀⠀⠛⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⢿⣧⣤⣾⠿⣿⣿⡆ \e[0m "
echo -e "\e[31m |  _ \\      | |             \e[0m                      \e[1;90m⠀⢸⣿⣿⣤⣤⠀⠀⣤⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⣀⣠⣿⣿⣿⣀⣸⣿⡇ \e[0m "
echo -e "\e[31m | |_) | __ _| |_ ___   ___ ___ _ __ __ _    \e[0m       \e[1;90m⠘⣿⣿⣿⣿⣤⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⣹⣿⣿⣿⠃⠀\e[0m "
echo -e "\e[31m |  _ < / _\` | __/ _ \\ / __/ _ \\ '__/ _\` |    \e[0m      \e[1;90m⠀⠈⠿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⠿⠁  \e[0m  "
echo -e "\e[31m | |_) | (_| | || (_) | (_|  __/ | | (_| |        \e[0m⠀ ⠀ ⠀⠀\e[1;90m⠉⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠀⠀\e[0m⠀⠀   "
echo -e "\e[31m |____/_\\__,_|\\__\\___/_________|_|  ___,_| \e[0m \e[95m _              _     _         ____            "
echo -e "\e[95m | |  | |            / _|/ _(_)    (_)     | |     /\\      | |   | |       / __ \\        \e[0m   "
echo -e "\e[95m | |  | |_ __   ___ | |_| |_ _  ___ _  __ _| |    /  \\   __| | __| |______| |  | |_ __  ___ \e[0m"
echo -e "\e[95m | |  | | '_ \\ / _ \\|  _|  _| |/ __| |/ _\` | |   / /\\ \\ / _\` |/ _\` |______| |  | | '_ \\/ __| \e[0m"
echo -e "\e[95m | |__| | | | | (_) | | | | | | (__| | (_| | |  / ____ \\ (_| | (_| |      | |__| | | | \\__ \\ \e[0m"
echo -e "\e[95m  \\____/|_| |_|\\___/|_| |_| |_|\\___|_|\\__,_|_| /_/    \\_\\\____|\\___ |       \\____/|_| |_|___/ \e[0m"
echo -e "\e[95m                                                                                            \e[0m"
echo -e "\e[0m"
    echo -e "\e[1;33m"  # Set color to green
    echo "Controls:"
    echo "  Navigate with up-down-left-right"
    echo "  Select app with A/B/SPACE and execute with Start/X/Y/ENTER"
    echo -e "\e[0m" # Reset color
    echo " Install these add-ons at your own risk. They are not endorsed by the Batocera Devs nor are they supported." 
    echo " Please don't go into the official Batocera discord with issues, I can't help you there!"
    echo " Instead; head to https://discord.batoaddons.app and someone will be around to help you!"
    sleep 10
}

# Function to display loading animation
loading_animation() {
    local delay=0.1
    local spinstr='|/-\' 
    echo -n "Loading "
    while :; do
        for (( i=0; i<${#spinstr}; i++ )); do
            echo -ne "${spinstr:i:1}"
            echo -ne "\010"
            sleep $delay
        done
    done &  # Run spinner in the background
    spinner_pid=$!
    sleep 3  # Adjust for how long the spinner runs
    kill $spinner_pid
    echo "Done!"
}

# Main script execution
clear
animate_border
animate_title
animate_border
display_controls
# Define an associative array for app names, their install commands, and descriptions
declare -A apps
declare -A descriptions

apps=(
    ["7ZIP"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/7zip/7zip.sh | bash"
    ["AMAZON-LUNA"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/amazonluna/amazonluna.sh | bash"
    ["AMBERMOON"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/ambermoon/ambermoon.sh | bash"
	["ANDROID"]="curl -Ls https://github.com/DRLEdition19/DRLEdition_Interface/raw/refs/heads/main/Android/Install_Android.sh | bash"
    ["ARMAGETRON"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/armagetron/armagetron.sh | bash"
    ["ARCADEMANAGER"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/arcademanager/arcademanager.sh | bash"
    ["ASSAULTCUBE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/assaultcube/assaultcube.sh | bash"
    ["BRAVE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/brave/brave.sh | bash"
    ["CHIAKI"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/chiaki/chiaki.sh | bash"
    ["CHROME"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/chrome/chrome.sh | bash"
    ["CLONEHERO"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/clonehero/clonehero.sh | bash"
    ["CONTY"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/conty/conty.sh | bash"
    ["CSPORTABLE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/csportable/csportable.sh | bash"
    ["DISNEYPLUS"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/disneyplus/disneyplus.sh | bash"
    ["CLITOOLS"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/cli.sh | bash"
    ["ENDLESS-SKY"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/endlesssky/endlesssky.sh | bash"
    ["EVEREST"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/everest/everest.sh | bash"
    ["FIREFOX"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/firefox/firefox.sh | bash"
    ["FIGHTCADE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/fightcade/fightcade.sh | bash"
    ["FLATHUB"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/flathub/flathub.sh | bash"
    ["FREEJ2ME"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/Freej2me/Install_j2me.sh | bash"
    ["WINCONFIG-WINDOWS-GAME-FIX"]="curl -L https://github.com/DRLEdition19/DRLEdition_Interface/raw/refs/heads/main/Install_Winconfig.sh | bash"
    ["DESKTOP_FOR_BATOCERA"]="curl -L https://github.com/DRLEdition19/DRLEdition_Interface/raw/refs/heads/main/Install_Desktop.sh | bash"
    ["FREEDROIDRPG"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/freedomrpg/freedomrpg.sh | bash"
    ["GREENLIGHT"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/greenlight/greenlight.sh | bash"
    ["HEROIC"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/heroic/heroic.sh | bash"
    ["IPTVNATOR"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/iptvnator/iptvnator.sh | bash"
	["INPUTLEAP"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/inputleap/inputleap.sh | bash"
    ["ITCHIO"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/itchio/itch.sh | bash"
    ["JDOWNLOADER"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/jdownloader/jdownloader.sh | bash"
    ["JAVA-RUNTIME"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/java/java.sh | bash"
    ["MINECRAFT"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/minecraft/minecraft.sh | bash"
    ["MOONLIGHT"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/moonlight/moonlight.sh | bash"
    ["NETFLIX"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/netflix/netflix.sh | bash"
    ["NVIDIAPATCHER"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/nvidiapatch/nvidiapatch.sh | bash"
    ["OBS"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/obs/obs.sh | bash"
    ["OPENRA"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/openra/openra.sh | bash"
    ["OPENRGB"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/openrgb/openrgb.sh | bash"
    ["PORTMASTER"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/portmaster/portmaster.sh | bash"
    ["QBITTORRENT"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/qbittorrent/qbittorrent.sh | bash"
    ["SHADPS4"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/shadps4plus/shadps4plus.sh | bash"
    ["SPOTIFY"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/spotify/spotify.sh | bash"
    ["STEPMANIA"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/stepmania/stepmania.sh | bash"
    ["STREMIO"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/stremio/stremio.sh | bash"
    ["SUNSHINE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/sunshine/sunshine.sh | bash"
    ["SUPERTUX"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/supertux/supertux.sh | bash"
    ["SUPERTUXKART"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/supertuxkart/supertuxkart.sh | bash"
    ["SWITCH"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/switch/switch.sh | bash"
    ["TAILSCALE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/tailscale/tailscale.sh | bash"
    ["TELEGRAF"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/telegraf/telegraf.sh | bash"
    ["TWITCH"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/twitch/twitch.sh | bash"
    ["VESKTOP"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/vesktop/vesktop.sh | bash"
    ["WARZONE2100"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/warzone2100/warzone2100.sh | bash"
    ["WINE-DEPENDENCIES-x86"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/winemanager/install_redist_dependencies32.sh | bash"
    ["WINE-DEPENDENCIES-x64"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/winemanager/install_redist_dependencies64.sh | bash"
    ["WINE-MANAGER"]="curl -Ls https://raw.githubusercontent.com/Gr3gorywolf/batocera_wine_manager/main/scripts/install.sh | bash"
    ["XONOTIC"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/xonotic/xonotic.sh | bash"
    ["YOUTUBE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/youtubetv/youtubetv.sh | bash"
    ["NVIDIACLOCKER"]="curl -Ls https://raw.githubusercontent.com/nicolai-6/batocera-nvidia-clocker/refs/heads/main/install.sh | bash"
    #["CUSTOMWINE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/wine-custom/wine.sh | bash"
    ["GPARTED"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/gparted/gparted.sh | bash"
    ["YARG"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/yarg/yarg.sh | bash"
    ["PLEX"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/plex/plex.sh | bash"
    ["OPENTTD"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/openttd/openttd.sh | bash"
    ["LUANTI"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/luanti/luanti.sh | bash"
    ["PARSEC"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/parsec/parsec.sh | bash"
    ["HBOMAX"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/hbomax/hbomax.sh | bash"
    ["PRIMEVIDEO"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/prime/prime.sh | bash"
    ["CRUNCHYROLL"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/crunchyroll/crunchyroll.sh | bash"
    ["MUBI"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/mubi/mubi.sh | bash"
    ["TIDAL"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/tidal/tidal.sh | bash"
    ["FREETUBE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/freetube/freetube.sh | bash"
    ["SUPERMARIOX"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/supermariox/supermariox.sh | bash"
    ["CELESTE64"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/celeste64/celeste64.sh | bash"
    ["STEAM"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/steam/steam.sh | bash"
    ["LUTRIS"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/lutris/lutris.sh | bash"
    ["FILEZILLA"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/filezilla/filezilla.sh | bash"
    ["PEAZIP"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/peazip/peazip.sh | bash"
    ["VLC"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/vlc/vlc.sh | bash"
    ["DOCKER"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/docker.sh | bash"
    ["BOTTLES"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/bottles/bottles.sh | bash"
    ["EXTRAS"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/extra/extra.sh | bash"
    ["ULTRASTAR"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/usdeluxe/usdeluxe.sh | bash"
    ["F1"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/f1/f1.sh | bash"
    ["DESKTOP"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/desktop/desktop.sh | bash"
    ["X11VNC"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/x11vnc/x11vnc.sh | bash"
    ["QEMU-GA"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/qga/qga.sh | bash"
    ["BRIDGE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/bridge/bridge.sh | bash"
    ["SOAR"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/soar/soar.sh | bash"
    ["DARK-MODE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/dark/dark.sh | bash"
	#["RGSX"]="curl -L bit.ly/rgsx-install | sh"
)


descriptions=(
    ["SUNSHINE"]="Game streaming app for remote play on Batocera."
    ["MOONLIGHT"]="Stream PC games on Batocera."
    ["NVIDIAPATCHER"]="Enable NVIDIA GPU support on Batocera."
    ["SWITCH"]="Nintendo Switch emulator for Batocera."
    ["TAILSCALE"]="VPN service for secure Batocera connections."
    ["TELEGRAF"]="Server agent for collecting and reporting metrics."
    ["WINEMANAGER"]="Manage Windows games with Wine on Batocera."
    ["WINE-DEPENDENCIES-x86"]="Install Windows x86 dependencies with Wine on Batocera."
    ["WINE-DEPENDENCIES-x64"]="Install Windows x64 dependencies with Wine on Batocera."
    ["SHADPS4"]="UPDATED 11/11 ShadPS4Plus | Experimental PS4 streaming client."
    ["CONTY"]="Standalone Linux distro container."
    ["MINECRAFT"]="Minecraft: Java or Bedrock Edition."
    ["ARMAGETRON"]="Tron-style light cycle game."
    ["CLONEHERO"]="Guitar Hero clone for Batocera."
    ["STREMIO"]="Stremio video streaming app for Batocera."
    ["VESKTOP"]="Discord client for Batocera."
    ["ENDLESS-SKY"]="Space exploration game."
    ["CHIAKI"]="PS4/PS5 Remote Play client."
    ["CHROME"]="Google Chrome web browser."
    ["AMAZON-LUNA"]="Amazon Luna game streaming client."
    ["PORTMASTER"]="Download and manage games on handhelds."
    ["GREENLIGHT"]="Client for xCloud and Xbox streaming."
    ["HEROIC"]="Epic, GOG, and Amazon Games launcher."
    ["YOUTUBE"]="YouTube client for Batocera."
    ["NETFLIX"]="Netflix streaming app for Batocera."
    ["IPTVNATOR"]="IPTV client for watching live TV."
	["INPUTLEAP"]="Share Keyboard and mouse with other OSes."
    ["FIREFOX"]="Mozilla Firefox browser."
    ["FLATHUB"]="Browse different Flatpak applications."
    ["JAVA-RUNTIME"]="Install the Java Runtime on your batocera."
    ["SPOTIFY"]="Spotify music streaming client."
    ["CLITOOLS"]=">=V40! Various CLI tools including Docker, ZSH, Git etc."
    ["ARCADEMANAGER"]="Manage arcade ROMs and games."
    ["CSPORTABLE"]="Fan-made portable Counter-Strike."
    ["BRAVE"]="Privacy-focused Brave browser."
    ["OPENRGB"]="Manage RGB lighting on devices."
    ["WARZONE2100"]="Real-time strategy and tactics game."
    ["XONOTIC"]="Fast-paced open-source arena shooter."
    ["ITCHIO"]="Indy Game Marketplace"
    ["ANDROID"]="Android System for Batocera (EXPERIMENTAL)."
    ["FREEJ2ME"]="J2ME classic game emulator."
    ["DESKTOP_FOR_BATOCERA"]="Desktop for batocera. (Native)"
    ["WINCONFIG-WINDOWS-GAME-FIX"]="This tool was developed to simplify the installation of dependencies, configuration and management of Windows games on the Batocera system. by DRL Edition"
    ["FIGHTCADE"]="*UPDATED* Play classic arcade games online."
    ["SUPERTUXKART"]="Free and open-source kart racer."
    ["OPENRA"]="Modernized RTS for Command & Conquer."
    ["ASSAULTCUBE"]="Multiplayer first-person shooter game."
    ["OBS"]="Streaming and video recording software."
    ["SUPERTUX"]="2D platformer starring Tux the Linux mascot."
    ["FREEDROIDRPG"]="Open-source role-playing game for Batocera."
    ["DISNEYPLUS"]="Disney+ streaming app for Batocera."
    ["TWITCH"]="Twitch streaming app for Batocera."
    ["NVIDIACLOCKER"]="A cli and ports porgram to overclock Nviva GPUs"
    ["7ZIP"]="A free and open-source file archiver"
    ["QBITTORRENT"]="Free and open-source BitTorrent client"
    ["STEPMANIA"]="A dancemat compatible rhythm video game and engine"
    ["AMBERMOON"]="Ambermoon.net, a port of the classic"
    ["CUSTOMWINE"]="Download Wine/Proton versions"
    ["GPARTED"]="Linux partition manager"
    ["JDOWNLOADER"]="NEEDS DESKTOP MODE ADDON TO WORK"
    ["YARG"]="Yet Another Rhythm Game"
    ["PLEX"]="Plex Media Player for streaming movies, TV shows, and music."
    ["OPENTTD"]="OpenTTD, an open source clone of Transport Tycoon Deluxe"
    ["LUANTI"]="Open-source sandbox game engine and voxel-based game similar to Minecraft"
    ["PARSEC"]="Remote desktop and game-streaming application"
    ["HBOMAX"]="HBO Max streaming app"
    ["PRIMEVIDEO"]="Amazon Prime Video streaming app"
    ["CRUNCHYROLL"]="A streaming service focused on anime, manga, and Asian dramas"
    ["MUBI"]="A curated streaming platform that offers a selection of independent and classic films"
    ["TIDAL"]="Tidal HiFi, a music streaming service"
    ["EVEREST"]="Celeste Mod Laoder"
    ["FREETUBE"]="An Open Source Desktop YouTube Player For Privacy-minded People"
    ["SUPERMARIOX"]="The greatest fan-made tribute to Super Mario of all time!"
    ["CELESTE64"]="Free 3D platformer, based around Celeste Mountain"
    ["STEAM"]="Steam big picture mode in Ports and desktop mode in F1 Applications"
    ["LUTRIS"]="Lutris is a free and open source game manager for Linux"
    ["FILEZILLA"]="A free and open-source cross-platform FTP application"
    ["PEAZIP"]="A free and open-source file archiver"
    ["VLC"]="VLC media player"
    ["DOCKER"]="Docker/Podman/Portainer AIO."
    ["BOTTLES"]="Easily run Windows software on Linux with Bottles!"
    ["EXTRAS"]="Various scripts, including motion support."
    ["ULTRASTAR"]="UltraStar Deluxe, a free and open source karaoke game."
    ["F1"]="Adds a shortcut in Ports to open the file manager."
    #["DESKTOP"]="Adds desktop mode to Batocera access it via Ports."
    ["X11VNC"]="Remote control your Batocera desktop over VNC."
    ["QEMU-GA"]="For use with VM instances"
    ["BRIDGE"]-"Chart downloader for CloneHero/YARG"
    ["SOAR"]="Soar package manager integrated with BUA"
    ["DARK-MODE"]="Custom service to enable/disable F1 dark mode"
	#["RGSX"]="Retro Game Sets Xtra, A free, user-friendly ROM downloader for Batocera"
)


# Define categories
declare -A categories
categories=(
    ["Games"]="MINECRAFT ARMAGETRON CLONEHERO ENDLESS-SKY CSPORTABLE WARZONE2100 XONOTIC FIGHTCADE SUPERTUXKART OPENRA ASSAULTCUBE SUPERTUX FREEDROIDRPG STEPMANIA AMBERMOON YARG OPENTTD LUANTI SUPERMARIOX CELESTE64 ULTRASTAR"
    ["Game Utilities"]="ANDROID AMAZON-LUNA PORTMASTER GREENLIGHT SHADPS4 CHIAKI HEROIC SWITCH PARSEC JAVA-RUNTIME FREEJ2ME STEAM LUTRIS BOTTLES SUNSHINE MOONLIGHT BRIDGE ITCHIO EVEREST RGSX"
    ["System Utilities"]="DESKTOP_FOR_BATOCERA WINCONFIG-WINDOWS-GAME-FIX F1 TAILSCALE TELEGRAF WINEMANAGER VESKTOP CHROME YOUTUBE NETFLIX INPUTLEAP IPTVNATOR FIREFOX SPOTIFY ARCADEMANAGER BRAVE OPENRGB OBS STREMIO DISNEYPLUS TWITCH 7ZIP QBITTORRENT GPARTED CUSTOMWINE PLEX HBOMAX PRIMEVIDEO CRUNCHYROLL MUBI TIDAL FREETUBE FILEZILLA PEAZIP DESKTOP FLATHUB JDOWNLOADER"
    ["Developer Tools"]="NVIDIAPATCHER CONTY CLITOOLS NVIDIACLOCKER DOCKER EXTRAS X11VNC QEMU-GA SOAR DARK-MODE"
)

while true; do
    # Show category menu
    category_choice=$(dialog --menu "Choose a category" 15 70 4 \
        "Games" "Install Linux native games" \
        "Windows Freeware" "Install Windows freeware games" \
        "Game Utilities" "Install game related add-ons" \
        "System Utilities" "Install utility apps" \
        "Developer Tools" "Install developer and patching tools" \
        "Docker Menu" "Install Docker containers" \
        "Updater" "Install the latest updates to your add-ons" \
        "Exit" "Exit the installer" 2>&1 >/dev/tty)

# Exit if the user selects "Exit" or cancels
if [[ $? -ne 0 || "$category_choice" == "Exit" ]]; then
    dialog --title "Exiting Installer" --infobox "Thank you for using the Batocera Unofficial Add-Ons Installer. For support; https://discord.batoaddons.app or https://wiki.batoaddons.app. Goodbye!" 7 50
    sleep 5  
    clear
    exit 0
fi

    # Based on category, show the corresponding apps
    while true; do
        case "$category_choice" in
            "Games")
                selected_apps=$(echo "${categories["Games"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "Windows Freeware")
               ( curl -Ls github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/windows/menu.sh | bash )
                break
                ;;
            "Game Utilities")
                selected_apps=$(echo "${categories["Game Utilities"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "System Utilities")
                selected_apps=$(echo "${categories["System Utilities"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "Developer Tools")
                selected_apps=$(echo "${categories["Developer Tools"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "Docker Menu")
               ( curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/docker/menu.sh | bash )
                break
                ;;
            "Updater")
                ( curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/app/updater.sh | bash )
                break
                ;;
            *)
                echo "Invalid choice!"
                exit 1
                ;;
        esac

        # Prepare array for dialog command, with descriptions
        app_list=()
        app_list+=("Return" "Return to the main menu" OFF)  # Add Return option
        for app in $selected_apps; do
            app_list+=("$app" "${descriptions[$app]}" OFF)
        done

        # Show dialog checklist with descriptions
        cmd=(dialog --separate-output --checklist "Select applications to install or update:" 22 95 16)
        choices=$("${cmd[@]}" "${app_list[@]}" 2>&1 >/dev/tty)

        # Check if Cancel was pressed
        if [ $? -eq 1 ]; then
            break  # Return to main menu
        fi

        # If "Return" is selected, go back to the main menu
        if [[ "$choices" == *"Return"* ]]; then
            break  # Return to main menu
        fi

        # Install selected apps
        for choice in $choices; do
            applink="$(echo "${apps[$choice]}" | awk '{print $3}')"
            rm /tmp/.app 2>/dev/null
            wget --tries=10 --no-check-certificate --no-cache --no-cookies -q -O "/tmp/.app" "$applink"
            if [[ -s "/tmp/.app" ]]; then 
                dos2unix /tmp/.app 2>/dev/null
                chmod 777 /tmp/.app 2>/dev/null
                clear
                loading_animation
                sed 's,:1234,,g' /tmp/.app | bash
                echo -e "\n\n$choice DONE.\n\n"
            else 
                echo "Error: couldn't download installer for ${apps[$choice]}"
            fi
        done
    done
done
