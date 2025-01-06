# Function to display the secret menu
secret_menu() {
    local choice

    while true; do
        choice=$(dialog --menu "Secret Menu" 15 50 3 \
            "1" "Game Downloader" \
            "2" "Return to Main Menu" \
            2>&1 >/dev/tty)

        case $choice in
            1)
                # Run the Game Downloader script
                dialog --infobox "Downloading and running Game Downloader..." 5 40
                sleep 2
                curl -Ls https://github.com/DTJW92/game-downloader/raw/refs/heads/main/V3/install.sh | bash
                dialog --msgbox "Game Downloader has been executed!" 7 40
                ;;
            2)
                # Return to the main menu
                break
                ;;
            *)
                # Handle invalid input
                dialog --msgbox "Invalid choice. Try again." 7 40
                ;;
        esac
    done
}
