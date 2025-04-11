#!/bin/bash

# Step 0: Install main addon dependencies
SYMLINK_MANAGER_PATH="/userdata/system/services/symlink_manager"
if [ ! -e "$SYMLINK_MANAGER_PATH" ]; then
    curl -Ls install.batoaddons.app | bash
fi

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed. Setting up batocera-containers..."

    # Download Docker & Podman container manager
    echo "Preparing & Downloading Docker & Podman..."
    directory="$HOME/batocera-containers"
    url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/batocera-containers"
    filename="batocera-containers"
    mkdir -p "$directory"
    cd "$directory"
    wget -q --show-progress "$url" -O "$filename"
    chmod +x "$filename"

    # Update ~/custom.sh to autostart batocera-containers
    startup="/userdata/system/batocera-containers/batocera-containers &"
    csh=/userdata/system/custom.sh
    if ! grep -Fq "$startup" "$csh" 2>/dev/null; then
        echo -e '#!/bin/bash\n\n'"$startup\n" > "$csh"
        dos2unix "$csh" 2>/dev/null
        chmod a+x "$csh"
    fi

    clear
    echo "Starting Docker..."
    ~/batocera-containers/batocera-containers

    # Install Portainer
    echo "Installing Portainer..."
    docker volume create portainer_data
    docker run --device /dev/dri:/dev/dri --privileged --net host --ipc host -d \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /media:/media \
        -v portainer_data:/data \
        portainer/portainer-ce:latest

    # Enable Docker service
    curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker -o /userdata/system/services/docker && chmod +x /userdata/system/services/docker
    batocera-services enable docker
    batocera-services start docker
else
    echo "Docker is already installed."
fi

# Step 3: Calculate appropriate shm size
total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ "$total_ram" -gt 14000000 ]; then
    shm_size="8gb"
elif [ "$total_ram" -gt 12000000 ]; then
    shm_size="6gb"
elif [ "$total_ram" -gt 8000000 ]; then
    shm_size="4gb"
elif [ "$total_ram" -gt 4000000 ]; then
    shm_size="2gb"
else
    shm_size="1gb"
fi

# Step 4: Distro selection with Alpine warning
while true; do
    echo "Select a base distro:"
    echo "1) alpine"
    echo "2) ubuntu"
    echo "3) fedora"
    echo "4) arch"
    echo "5) debian"
    echo -n "Enter number (1-5): "
    read -r choice < /dev/tty
    case "$choice" in
        1)
            distro="alpine"
            echo
            echo "WARNING: Alpine-based Webtop images do NOT support NVIDIA GPU passthrough."
            echo "If you plan to use GPU acceleration, choose another distro like Ubuntu or Arch."
            echo -n "Continue with Alpine or go back? [c = continue, b = back]: "
            read -r response < /dev/tty
            [[ "${response,,}" == "c" ]] && break
            ;;
        2) distro="ubuntu"; break ;;
        3) distro="fedora"; break ;;
        4) distro="arch"; break ;;
        5) distro="debian"; break ;;
        *) echo "Invalid input. Try again." ;;
    esac
done

# Step 5: Desktop environment selection
while true; do
    echo "Select a desktop environment:"
    echo "1) xfce"
    echo "2) kde"
    echo "3) mate"
    echo "4) i3"
    echo "5) openbox"
    echo "6) icewm"
    echo -n "Enter number (1-6): "
    read -r de_choice < /dev/tty
    case "$de_choice" in
        1) env="xfce"; break ;;
        2) env="kde"; break ;;
        3) env="mate"; break ;;
        4) env="i3"; break ;;
        5) env="openbox"; break ;;
        6) env="icewm"; break ;;
        *) echo "Invalid input. Try again." ;;
    esac
done

# Step 6: Determine image tag
[[ "$distro" == "alpine" && "$env" == "xfce" ]] && tag="latest" || tag="$distro-$env"

# Final confirmation
echo "You selected: $tag"
echo -n "Proceed with installation? [y/N]: "
read -r confirm < /dev/tty
[[ "${confirm,,}" != "y" ]] && echo "Installation cancelled." && exit 1

# Step 7: Run Docker Webtop container
docker run -d \
    --name=desktop \
    --security-opt seccomp=unconfined \
    -e PUID=$(id -u) \
    -e PGID=$(id -g) \
    -e TZ=$(cat /etc/timezone) \
    -e SUBFOLDER=/ \
    -e TITLE="Webtop ($distro $env)" \
    -v /userdata:/config/ \
    --device /dev/dri:/dev/dri \
    --device /dev/bus/usb:/dev/bus/usb \
    -p 3000:3000 \
    --shm-size=$shm_size \
    --restart unless-stopped \
    lscr.io/linuxserver/webtop:$tag

# Step 8: Install Google Chrome AppImage
echo "Installing Google Chrome AppImage..."
if ! command -v jq >/dev/null 2>&1; then
    echo "Missing dependency: jq is required. Please install jq and re-run."
    exit 1
fi
appimage_url=$(curl -s https://api.github.com/repos/ivan-hc/Chrome-appimage/releases/latest | jq -r '.assets[] | select(.name | endswith(".AppImage") and contains("Google-Chrome-stable")) | .browser_download_url')
mkdir -p /userdata/system/add-ons/google-chrome/extra
wget -q --show-progress -O /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage "$appimage_url"
chmod +x /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage

# Step 9: Create launcher in Ports
echo "Creating BatoDesktop launcher in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/BatoDesktop.sh
#!/bin/bash
DISPLAY=:0.0 /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage --no-sandbox --test-type --start-fullscreen --force-device-scale-factor=1.6 'http://localhost:3000'
EOF
chmod +x /userdata/roms/ports/BatoDesktop.sh

# Step 10: Add controller support
cat << 'EOF' > /userdata/roms/ports/BatoDesktop.sh.keys
{
    "actions_player1": [
        {"trigger": "up", "type": "key", "target": "KEY_UP"},
        {"trigger": "down", "type": "key", "target": "KEY_DOWN"},
        {"trigger": "left", "type": "key", "target": "KEY_LEFT"},
        {"trigger": "right", "type": "key", "target": "KEY_RIGHT"},
        {"trigger": "b", "type": "key", "target": "KEY_ENTER"},
        {"trigger": "start", "type": "key", "target": "KEY_ENTER"},
        {"trigger": "joystick1up", "type": "key", "target": "KEY_UP"},
        {"trigger": "joystick1down", "type": "key", "target": "KEY_DOWN"},
        {"trigger": "joystick1left", "type": "key", "target": "KEY_LEFT"},
        {"trigger": "joystick1right", "type": "key", "target": "KEY_RIGHT"},
        {"trigger": "select", "type": "key", "target": "KEY_ESC"},
        {"trigger": "a", "type": "key", "target": "KEY_ESC"},
        {"trigger": "pageup", "type": "exec", "target": "batocera-audio setSystemVolume -5"},
        {"trigger": "pagedown", "type": "exec", "target": "batocera-audio setSystemVolume +5"},
        {"trigger": "l2", "type": "exec", "target": "batocera-audio setSystemVolume -5"},
        {"trigger": "r2", "type": "exec", "target": "batocera-audio setSystemVolume +5"},
        {"trigger": "joystick2", "type": "mouse"},
        {"trigger": ["hotkey", "start"], "type": "key", "target": ["KEY_LEFTALT", "KEY_F4"]},
        {"trigger": "r3", "type": "key", "target": "BTN_LEFT"}
    ]
}
EOF

# Step 11: Refresh Ports menu
echo "Refreshing Ports menu..."
curl -s http://127.0.0.1:1234/reloadgames

# Step 12: Done!
echo "BatoDesktop installed successfully. Launch from the Ports menu!"

# Step 13: Add the image and marquee
echo "Adding image and marquee to the game list..."

gamelist_file="/userdata/roms/ports/gamelist.xml"
logo_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/desktop/extra/desktop-logo.png"
marquee_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/desktop/extra/desktop-marquee.png"

# Ensure the image and marquee directories exist
mkdir -p /userdata/roms/ports/images

logo_path="/userdata/roms/ports/images/desktop-logo.png"
marquee_path="/userdata/roms/ports/images/desktop-marquee.png"

# Download the logo and marquee
curl -L -o "$logo_path" "$logo_url"
curl -L -o "$marquee_path" "$marquee_url"

# XML entry for the game
xml_entry="<game>
    <path>/userdata/roms/ports/BatoDesktop.sh</path>
    <name>Desktop</name>
    <image>$logo_path</image>
    <marquee>$marquee_path</marquee>
    <command>/userdata/roms/ports/BatoDesktop.sh</command>
</game>"

# Ensure the gamelist.xml exists
if [ ! -f "$gamelist_file" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$gamelist_file"
fi

# Append the XML entry above </gameList> safely
temp_file=$(mktemp)
awk -v entry="$xml_entry" '
  /<\/gameList>/ {
    print entry
  }
  { print }
' "$gamelist_file" > "$temp_file" && mv "$temp_file" "$gamelist_file"

echo "Game added to gamelist.xml."
