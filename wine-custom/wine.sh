#!/bin/bash

# Define the options
OPTIONS=("1" "Wine & Proton (vanilla/regular)" "2" "Wine-TKG-Staging" "3" "Wine-GE Custom" "4" "GE-Proton" "5" "Steamy-AIO Wine Dependency Installer" "6" "V40 Stock Wine")

# Use dialog to display the menu
CHOICE=$(dialog --clear --backtitle "Wine Installation" \
                --title "Select a Version..." \
                --menu "Choose a Wine version to install:" \
                15 50 4 \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

# Clear the dialog artifacts
clear

# Run the appropriate script based on the user's choice
case $CHOICE in
    1)
        echo "You chose Wine Vanilla and Proton."
        curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/vanilla.sh | bash
        ;;
    2)
        echo "You chose Wine-tkg staging."
        curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/tkg.sh | bash
        ;;

    3)
        echo "You chose Wine-GE Custom."
        curl -L  https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/wine-ge.sh | bash
        ;;
    4)
        echo "You chose GE-Proton."
        curl -L  https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/ge-proton.sh | bash
        ;;
    5)
        echo "You chose Steamy-AIO."
        curl -L  https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/steamy.sh | bash
        ;;
    6)
        echo "You chose V40 stock wine."
        curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/v40wine/v40wine.sh | bash
        ;;
     *)
        echo "Invalid choice or no choice made. Exiting."
        ;;
esac
