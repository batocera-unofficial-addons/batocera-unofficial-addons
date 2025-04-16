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
    url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/batocera-containers"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: aarch64 detected."
    url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/batocera-containers-aarch64"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "Preparing & Downloading Docker & Podman..."

    # Define the directory and target filename
    directory="$HOME/batocera-containers"
    filename="batocera-containers"

    # Create the directory if it doesn't exist
    mkdir -p "$directory"

    # Change to the directory
    cd "$directory"

    # Download the correct binary as 'batocera-containers'
    wget -q --show-progress "$url" -O "$filename"

    # Make it executable
    chmod +x "$filename"
    echo "File '$filename' downloaded and made executable in '$directory/$filename'"

    # Add to startup script if not already added
    custom_startup="/userdata/system/custom.sh"
    restore_script="/userdata/system/batocera-containers/$filename"

    if ! grep -q "$restore_script" "$custom_startup" 2>/dev/null; then
        echo "Adding batocera-containers to startup..."
        echo "bash $restore_script &" >> "$custom_startup"
    fi
    chmod +x "$custom_startup"

    cd "$directory"

    clear
    echo "Starting Docker..."
    echo ""
    ./batocera-containers

    # Install Portainer
    echo "Installing Portainer..."
    echo ""
    docker volume create portainer_data
    docker run --device /dev/dri:/dev/dri --privileged --net host --ipc host -d --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /media:/media \
        -v portainer_data:/data \
        portainer/portainer-ce:latest

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

# Pull latest image (in case it's new or missing)
docker pull lscr.io/linuxserver/webtop:$tag

# Remove old webtop images (except the one we just pulled)
keep=$(docker images -q lscr.io/linuxserver/webtop:$tag)
images=$(docker images --filter=reference='lscr.io/linuxserver/webtop:*' -q | grep -v "$keep")

if [ -n "$images" ]; then
    docker rmi $images
fi

# Remove container and run fresh
docker rm -f desktop || true && \
docker run -d \
  --name=desktop \
  --security-opt seccomp=unconfined \
  --device /dev/dri:/dev/dri \
  --device /dev/bus/usb:/dev/bus/usb \
  --device /dev/snd \
  --group-add audio \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone) \
  -e SUBFOLDER=/ \
  -e TITLE="Webtop ($distro $env)" \
  -v /userdata:/config/ \
  -p 3000:3000 \
  --shm-size=$shm_size \
  --restart unless-stopped \
  lscr.io/linuxserver/webtop:$tag



# Step 8: Install browser depending on architecture
echo "Detecting system architecture..."
arch=$(uname -m)

mkdir -p /userdata/system/add-ons/batodesktop/extra
mkdir -p /userdata/roms/ports
arch=$(uname -m)
install_dir="/userdata/system/add-ons/desktop"
bin_path="$install_dir/desktop"
host_ip=$(ip addr show | awk '/inet / && $2 !~ /^127/ {print $2}' | cut -d/ -f1 | head -n1)
[ -z "$host_ip" ] && host_ip="localhost"

mkdir -p "$install_dir"

if [ "$arch" == "x86_64" ]; then
    echo "Downloading Desktop wrapper for x86_64..."
    url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/desktop.tar.xz"
elif [ "$arch" == "aarch64" ]; then
    echo "Downloading Desktop wrapper for ARM64..."
    url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/desktop-arm64.tar.xz"
else
    echo "❌ Unsupported architecture: $arch. Exiting."
    exit 1
fi

archive_path="$install_dir/desktop.tar.xz"

# Download and extract with folder stripping
wget -q --show-progress -O "$archive_path" "$url"
tar -xf "$archive_path" -C "$install_dir" --strip-components=1
rm "$archive_path"
chmod +x "$bin_path"

# Step: Create launcher in Ports
echo "Creating Desktop launcher in Ports..."
cat << EOF > /userdata/roms/ports/BatoDesktop.sh
#!/bin/bash
batocera-mouse show
QT_SCALE_FACTOR="1" \
GDK_SCALE="1" \
DISPLAY=:0.0 \
/userdata/system/add-ons/desktop/desktop --no-sandbox
EOF

chmod +x /userdata/roms/ports/BatoDesktop.sh


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
curl -Ls -o "$logo_path" "$logo_url"
curl -Ls -o "$marquee_path" "$marquee_url"

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


# Step 12: Done!
echo "BatoDesktop installed successfully. Launch from the Ports menu!"
sleep 5
