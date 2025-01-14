#!/bin/bash

# Get the machine hardware name
architecture=$(uname -m)

# Check if the architecture is x86_64 (AMD/Intel)
if [ "$architecture" != "x86_64" ]; then
    echo "This script only runs on AMD or Intel (x86_64) CPUs, not on $architecture."
    exit 1
fi

MESSAGE="This container is compatible with EXT4 or BTRFS partitions only!  FAT32/NTFS/exFAT are not supported.  Continue?"

# Use dialog to create a yes/no box
if dialog --title "Compatibility Warning" --yesno "$MESSAGE" 10 70; then
    # If the user chooses 'Yes', continue the installation
    echo "Continuing installation..."
    # Add your installation commands here
else
    # If the user chooses 'No', exit the script
    echo "Installation aborted by user."
    exit 1
fi


MESSAGE="WARNING: Batocera's Custom SDL/kernel mods appear to break XINPUT over BLUETOOTH on apps in the Arch container. Xbox One/S/X controllers are verified working via wired USB or Xbox wireless adapter only. 8bitDO controller users can switch their input mode to d-input or switch input.  Continue?"

# Use dialog to create a yes/no box
if dialog --title "Compatibility Warning" --yesno "$MESSAGE" 10 70; then
    # If the user chooses 'Yes', continue the installation
    echo "Continuing installation..."
    # Add your installation commands here
else
    # If the user chooses 'No', exit the script
    echo "Installation aborted by user."
    exit 1
fi

# Clear the screen after the dialog is closed
clear


echo "Starting Arch Contaniner Installer Script..."

sleep 2

clear 

# Function to display animated title
animate_title() {
    local text="Arch container installer"
    local delay=0.1
    local length=${#text}

    for (( i=0; i<length; i++ )); do
        echo -n "${text:i:1}"
        sleep $delay
    done
    echo
}

display_controls() {
    echo 
    echo "This Will install Steam, Heroic-Games Launcher, Lutris,"
    echo "and more apps in an Arch container with"
    echo "a new system appearing in ES called Arch Container or"
    echo "Linux depending on your theme in /userdata/system/add-ons/arch"  
    echo 
    sleep 10  # Delay for 10 seconds
}

###############

# Main script execution
clear
animate_title
display_controls
# Define variables
BASE_DIR="/userdata/system/add-ons/arch"
HOME_DIR="$BASE_DIR/home"
DOWNLOAD_URL="profork/conty.sh"
DOWNLOAD_FILE="$BASE_DIR/conty.sh"
ROMS_DIR="/userdata/roms/ports"

###############

# Step 1: Create base folder if not exists
mkdir -p "$BASE_DIR"
if [ ! -d "$BASE_DIR" ]; then
  # Handle error or exit if necessary
  echo "Error creating BASE_DIR."
  exit 1
fi

###############

# Step 2: Create home folder if not exists
if [ ! -d "$HOME_DIR" ]; then
  mkdir -p "$HOME_DIR"
fi

########
#make steam2 folder for steam shortcuts
mkdir -p /userdata/roms/steam2
###############

# Step 3: Download conty.sh with download percentage indicator


# Step 3: Download conty.sh parts with progress indicator
echo "Preparing to download conty.sh parts..."

# Ensure the target directory exists
mkdir -p /userdata/system/add-ons/arch
cd /userdata/system/add-ons/arch || { echo "Failed to access /userdata/system/add-ons/arch"; exit 1; }

# Clean any previous downloads
rm -f conty_part_* conty.sh
                                                                                                                                                                                                                 echo "Downloading conty.sh parts to /userdata/system/add-ons/arch..."

# Download each part with progress messages
for i in 1 2 3; do
  echo "Downloading conty_part_$i..."
  curl -L --progress-bar -o "conty_part_$i" "https://github.com/trashbus99/profork/releases/download/r1/conty_part_$i" || { echo "Download failed for conty_part_$i"; exit 1; }
done

# Verify all parts exist
for i in 1 2 3; do
  if [ ! -f "conty_part_$i" ]; then
    echo "Error: conty_part_$i not found."
    exit 1
  fi
done

echo "Combining conty_part_1, conty_part_2, and conty_part_3 into conty.sh..."
cat conty_part_1 conty_part_2 conty_part_3 > conty.sh || { echo "Failed to combine parts."; exit 1; }


# Verify the combined file exists
if [ -f "conty.sh" ]; then
  echo "Combination complete: conty.sh is ready."
else
  echo "Error: conty.sh was not created."
  exit 1
fi

# Clean up split parts
echo "Cleaning up part files..."
rm -f conty_part_*

# Make conty.sh executable
chmod +x conty.sh || { echo "Failed to make conty.sh executable."; exit 1; }

echo "Download, combination, and setup of conty.sh complete."

###############

# Step 4: Make conty.sh executable
chmod +x "$DOWNLOAD_FILE"

###############



# Update shortcuts
wget -q --tries=30 --no-check-certificate --no-cache --no-cookies --tries=50 -O /tmp/update_shortcuts.sh https://github.com/DTJW92/batocera-unofficial-addons/raw/main/arch/update-shortcuts.sh
dos2unix /tmp/update_shortcuts.sh 2>/dev/null
chmod 777 /tmp/update_shortcuts.sh 2>/dev/null
bash /tmp/update_shortcuts.sh 
sleep 1

###############

#echo "Launching Steam"
#dos2unix "/userdata/roms/conty/Steam Big Picture Mode.sh" 2>/dev/null
#chmod 777 "/userdata/roms/conty/Steam Big Picture Mode.sh" 2>/dev/null
#bash "/userdata/roms/conty/Steam Big Picture Mode.sh"

###############

MSG="Install Done. \nRefresh ES to see new system. \nYou should see a new system  in EmulationStation called Linux or Arch Container depending on theme\nNVIDIA Users: Drivers will download in the background on First app start-up & can take a while."
dialog --title "Arch Container Setup Complete" --msgbox "$MSG" 20 70

###############

