#!/bin/bash

# Function to handle the "Install Arch Container" option
install_arch_container() {
    echo "Installing Arch Container..."
    curl -L https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/arch/install.sh | bash
}

# Function to handle the "Uninstall Arch Container" option
uninstall_arch_container() {
    echo "Uninstalling Arch Container..."
    curl -L https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/arch/uninstall.sh | bash
}

# Function to handle the "Update Shortcuts" option
update_shortcuts() {
    echo "Updating Shortcuts..."
    curl -L https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/arch/update-shortcuts.sh | bash
}

while true; do
    CHOICE=$(dialog --clear \
        --backtitle "Arch Container Menu" \
        --title "Main Menu" \
        --menu "Choose an option:" 15 50 4 \
        "Return" "Return to the main menu" \
        "Install" "Install the Arch Linux container" \
        "Uninstall" "Remove the Arch Linux container" \
        "Update Shortcuts" "Update user-defined shortcuts" \
        2>&1 >/dev/tty)

    # Check if Cancel was pressed
    if [ $? -eq 1 ]; then
        break  # Return to main menu
    fi

    # If "Return" is selected, go back to the main menu
    if [[ "$CHOICE" == "Return" ]]; then
        break  # Return to main menu
    fi

    clear

    case $CHOICE in
        "Install Arch Container")
            install_arch_container
            ;;
        "Uninstall Arch Container")
            uninstall_arch_container
            ;;
        "Update Shortcuts")
            update_shortcuts
            ;;
        *)
            echo "Invalid option: $CHOICE"
            ;;
    esac

done

exit 0
