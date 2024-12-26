#!/bin/bash

# Step 1: Fetch the latest PortMaster installer URL
echo "Fetching the latest PortMaster release..."
installer_url=$(curl -s https://api.github.com/repos/PortsMaster/PortMaster-GUI/releases/latest | grep "browser_download_url" | grep "Install.Full.PortMaster.sh" | cut -d '"' -f 4)

if [ -z "$installer_url" ]; then
    echo "Failed to retrieve the latest PortMaster installer URL."
    exit 1
fi

echo "Latest installer found: $installer_url"

# Step 2: Download the PortMaster installer
echo "Downloading PortMaster installer..."
mkdir -p /userdata/system/add-ons/portmaster
wget -q -O /userdata/system/add-ons/portmaster/Install.Full.PortMaster.sh "$installer_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the PortMaster installer."
    exit 1
fi

# Step 3: Make the installer executable
chmod +x /userdata/system/add-ons/portmaster/Install.Full.PortMaster.sh
echo "PortMaster installer downloaded and marked as executable."

# Step 4: Run the installer
echo "Running the PortMaster installer..."
/userdata/system/add-ons/portmaster/Install.Full.PortMaster.sh

if [ $? -ne 0 ]; then
    echo "PortMaster installation failed."
    exit 1
fi

echo
echo "Installation complete! You can now launch PortMaster from the Ports menu."
curl http://127.0.0.1:1234/reloadgames
