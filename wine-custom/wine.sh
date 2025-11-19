#!/bin/bash

# Use dialog menu to display the selection menu
CHOICE=$(dialog --stdout --title "Select Wine Version" --menu "Choose which Wine/Proton version to install:" 20 70 6 \
    "vanilla" "Wine & Proton (vanilla/regular)" \
    "tkg" "Wine-TKG-Staging" \
    "wine-ge" "Wine-GE Custom" \
    "ge-proton" "GE-Proton" \
    "steamy" "Steamy-AIO Wine Dependency Installer" \
    "v40" "V40 Stock Wine")

if [ -z "$CHOICE" ]; then
    echo "Installation cancelled."
    exit 1
fi

# Run the appropriate script based on the user's choice
case $CHOICE in
    vanilla)
        echo "You chose Wine Vanilla and Proton."
        curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/vanilla.sh | bash
        ;;
    tkg)
        echo "You chose Wine-tkg staging."
        curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/tkg.sh | bash
        ;;
    wine-ge)
        echo "You chose Wine-GE Custom."
        curl -L  https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/wine-ge.sh | bash
        ;;
    ge-proton)
        echo "You chose GE-Proton."
        curl -L  https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/ge-proton.sh | bash
        ;;
    steamy)
        echo "You chose Steamy-AIO."
        curl -L  https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wine-custom/steamy.sh | bash
        ;;
    v40)
        echo "You chose V40 stock wine."
        curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/v40wine/v40wine.sh | bash
        ;;
    *)
        echo "Invalid choice or no choice made. Exiting."
        ;;
esac
