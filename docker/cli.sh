#!/bin/bash

# Architecture check
architecture=$(uname -m)
if [ "$architecture" != "x86_64" ]; then
    echo "This script only runs on AMD or Intel (x86_64) CPUs, not on $architecture."
    exit 1
fi

cli_apps="• Zsh (with Oh My Zsh, plugins, Powerlevel10k, .zshrc, and p10k.zsh)
• Fish (with Oh My Fish)
• Git
• Docker
• Podman
• Distrobox
• Exa
• Bat / Batcat
• Glances
• Aria2c
• Bandwhich
• Btop
• Dua
• Duf
• Fzf
• Hyperfine
• Icdiff
• Micro
• Neofetch
• Procs
• Ranger
• Rgrep
• Rip
• Scc
• Screenfetch
• Sd
• Speedtest-cli
• Strings
• Tldr
• Transfersh
• Tre
• Xmlstarlet
• Zoxide"


# Show available apps
dialog --title "Batocera-CLI Available Tools" --msgbox "The following CLI apps are included:\n$cli_apps" 30 70

# Confirm installation
dialog --stdout --title "Continue Installation?" --yesno "Would you like to proceed with installing the Batocera-CLI package?" 8 60
if [[ $? -ne 0 ]]; then
    dialog --title "Installation Canceled" --msgbox "The installation has been canceled." 8 60
    exit 1
fi

# Check for running Docker
if pgrep -x "dockerd" >/dev/null; then
    dialog --title "Error" --msgbox "Docker is currently running. Please stop or remove it first — CLI Tools includes its own Docker setup." 8 60
    exit 1
fi

# Start download
dialog --title "Downloading" --msgbox "Downloading and extracting Batocera-CLI..." 8 60

DESTINATION_DIR="/userdata/system"
FILENAME="cli.tar.xz"
DOWNLOAD_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages/cli.tar.xz"

mkdir -p "$DESTINATION_DIR"
cd "$DESTINATION_DIR"

curl -L "$DOWNLOAD_URL" -o "$FILENAME"
if [[ $? -ne 0 ]]; then
    dialog --title "Error" --msgbox "Download failed. Please check your connection and try again." 8 60
    exit 1
fi

tar -xJf "$FILENAME" -C "$DESTINATION_DIR"
rm -f "$FILENAME"
chmod +x "$DESTINATION_DIR/cli/run"

# Inform the user
dialog --title "Installation Complete" --msgbox "Batocera-CLI has been installed.\n\nYou can run it manually with:\n\n  bash /userdata/system/cli/run" 10 70

exit 0
