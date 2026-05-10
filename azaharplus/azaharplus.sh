#!/bin/bash

# Variables
install_dir="/userdata/system/add-ons/azaharplus"
es_config_dir="/userdata/system/configs/emulationstation"
user_site="/userdata/system/.local/lib/$(python3 -c 'import sys; print(f"python{sys.version_info.major}.{sys.version_info.minor}")')/site-packages"
base_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/azaharplus"
bua_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app"

# Ensure BUA Python hook is present
if [ ! -f "$user_site/usercustomize.py" ]; then
    echo "Installing BUA Python hook..."
    mkdir -p "$user_site"
    wget -q --show-progress -O "$user_site/usercustomize.py" "$bua_url/usercustomize.py"
fi

# Prepare installation directory
echo "Setting up installation directory at $install_dir..."
rm -rf "$install_dir"
mkdir -p "$install_dir/generator/azaharplus"
mkdir -p "$es_config_dir"

# Get latest AzaharPlus release URL
echo "Fetching latest AzaharPlus release..."
azaharplus_url=$(curl -s https://api.github.com/repos/AzaharPlus/AzaharPlus/releases/latest \
    | grep browser_download_url \
    | grep "linux.*\.zip" \
    | head -1 \
    | cut -d '"' -f 4)

if [ -z "$azaharplus_url" ]; then
    echo "Failed to fetch AzaharPlus release URL. Please check your internet connection."
    exit 1
fi

# Download AzaharPlus
echo "Downloading AzaharPlus..."
wget -q --show-progress -O "$install_dir/azaharplus.zip" "$azaharplus_url"

if [ $? -ne 0 ]; then
    echo "Failed to download AzaharPlus."
    exit 1
fi

# Extract AppImage
echo "Extracting AppImage..."
unzip -q "$install_dir/azaharplus.zip" -d "$install_dir"
mv "$install_dir"/azaharplus-*/azahar.AppImage "$install_dir/azahar.AppImage"
rm -rf "$install_dir"/azaharplus-* "$install_dir/azaharplus.zip"
chmod +x "$install_dir/azahar.AppImage"

# Download generator
echo "Downloading generator..."
wget -q --show-progress -O "$install_dir/generator/azaharplus/__init__.py" "$base_url/generator/azaharplus/__init__.py"
wget -q --show-progress -O "$install_dir/generator/azaharplus/azaharplusGenerator.py" "$base_url/generator/azaharplus/azaharplusGenerator.py"

# Download and deploy ES config files
echo "Downloading ES configs..."
wget -q --show-progress -O "$es_config_dir/es_systems_3ds.cfg" "$base_url/extra/es_systems_3ds.cfg"
wget -q --show-progress -O "$es_config_dir/es_features_azaharplus.cfg" "$base_url/extra/es_features_azaharplus.cfg"

# Extract icon from AppImage
echo "Extracting icon..."
mkdir -p "$install_dir/extra"
mkdir -p /tmp/azahar-icon-extract
cd /tmp/azahar-icon-extract
"$install_dir/azahar.AppImage" --appimage-extract 'usr/share/icons/hicolor/scalable/apps/org.azahar_emu.Azahar.svg' 2>/dev/null
rsvg-convert -w 128 -h 128 \
    /tmp/azahar-icon-extract/squashfs-root/usr/share/icons/hicolor/scalable/apps/org.azahar_emu.Azahar.svg \
    -o "$install_dir/extra/icon.png"
rm -rf /tmp/azahar-icon-extract
cd /

# Create persistent desktop entry
echo "Creating desktop entry..."
desktop_file="/usr/share/applications/AzaharPlus.desktop"
persistent_desktop="/userdata/system/configs/azaharplus/AzaharPlus.desktop"
mkdir -p /userdata/system/configs/azaharplus
cat <<DESKTOP > "$persistent_desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=AzaharPlus
Exec=$install_dir/azahar.AppImage
Icon=$install_dir/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
DESKTOP
chmod +x "$persistent_desktop"
cp "$persistent_desktop" "$desktop_file"
chmod +x "$desktop_file"

# Restore desktop entry on boot
restore_script="/userdata/system/configs/azaharplus/restore_desktop_entry.sh"
cat <<RESTORE > "$restore_script"
#!/bin/bash
if [ ! -f "$desktop_file" ]; then
    cp "$persistent_desktop" "$desktop_file"
    chmod +x "$desktop_file"
fi
RESTORE
chmod +x "$restore_script"
if ! grep -q "$restore_script" /userdata/system/custom.sh; then
    echo "bash \"$restore_script\" &" >> /userdata/system/custom.sh
fi
chmod +x /userdata/system/custom.sh

# Finish
echo "AzaharPlus installation complete."
killall -9 emulationstation
