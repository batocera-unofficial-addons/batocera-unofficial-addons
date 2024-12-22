#!/bin/bash

# Step 1: Create Fightcade directory
echo "Creating directory for Fightcade..."
mkdir -p /userdata/roms/fightcade

# Step 2: Download Fightcade (adjust URL as necessary)
echo "Downloading Fightcade..."
cd /userdata/roms/fightcade
wget https://fightcade.com/downloads/FightcadeInstaller.exe

# Step 3: Run Fightcade installer using the specified Wine path
echo "Running Fightcade installer..."
/usr/wine/ge-custom/bin/wine FightcadeInstaller.exe

# Step 4: Clean up the installer
echo "Cleaning up..."
rm FightcadeInstaller.exe

# Step 5: Create a shortcut to launch Fightcade from Batocera menu
echo "Creating Batocera shortcut..."
cat > /userdata/system/.config/autostart/fightcade.desktop <<EOL
[Desktop Entry]
Name=Fightcade
Exec=/usr/wine/ge-custom/bin/wine /userdata/roms/fightcade/Fightcade.exe
Type=Application
Icon=gnome-app-install
Comment=Fightcade Game Launcher
Categories=Game;
EOL

echo "Fightcade installation is complete!"
