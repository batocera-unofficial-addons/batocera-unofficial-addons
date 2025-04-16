#!/bin/bash

# Step 0: Install main addon dependencies
SYMLINK_MANAGER_PATH="/userdata/system/services/symlink_manager"
if [ ! -e "$SYMLINK_MANAGER_PATH" ]; then
    curl -Ls install.batoaddons.app | bash
fi

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

case "$arch" in
    x86_64)
        echo "Architecture: x86_64 detected."
        url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/batocera-containers"
        ;;
    aarch64)
        echo "Architecture: aarch64 detected."
        url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/batocera-containers-aarch64"
        ;;
    *)
        echo "Unsupported architecture: $arch. Exiting."
        exit 1
        ;;
esac

# Step 2: Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "Preparing & Downloading Docker & Podman..."

    directory="$HOME/batocera-containers"
    filename="batocera-containers"

    mkdir -p "$directory"
    cd "$directory"

    wget -q --show-progress "$url" -O "$filename"
    chmod +x "$filename"

    custom_startup="/userdata/system/custom.sh"
    restore_script="/userdata/system/batocera-containers/$filename"

    if ! grep -q "$restore_script" "$custom_startup" 2>/dev/null; then
        echo "Adding batocera-containers to startup..."
        echo "bash $restore_script &" >> "$custom_startup"
    fi
    chmod +x "$custom_startup"

    clear
    echo "Starting Docker..."
    ./batocera-containers

    echo "Installing Portainer..."
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

# Step 3: Calculate shm size
total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ "$total_ram" -gt 14000000 ]; then shm_size="8gb"
elif [ "$total_ram" -gt 12000000 ]; then shm_size="6gb"
elif [ "$total_ram" -gt 8000000 ]; then shm_size="4gb"
elif [ "$total_ram" -gt 4000000 ]; then shm_size="2gb"
else shm_size="1gb"
fi

# Step 4: Select base distro
while true; do
    echo "Select a base distro:"
    echo "1) alpine"
    echo "2) ubuntu"
    echo "3) fedora"
    echo "4) arch"
    echo "5) debian"
    read -rp "Enter number (1-5): " choice < /dev/tty
    case "$choice" in
        1)
            distro="alpine"
            echo -e "\n⚠️  Alpine does NOT support NVIDIA GPU passthrough.\n"
            read -rp "Continue with Alpine or go back? [c = continue, b = back]: " response < /dev/tty
            [[ "${response,,}" == "c" ]] && break
            ;;
        2) distro="ubuntu"; break ;;
        3) distro="fedora"; break ;;
        4) distro="arch"; break ;;
        5) distro="debian"; break ;;
        *) echo "Invalid input. Try again." ;;
    esac
done

# Step 5: Select desktop environment
while true; do
    echo "Select a desktop environment:"
    echo "1) xfce"
    echo "2) kde"
    echo "3) mate"
    echo "4) i3"
    echo "5) openbox"
    echo "6) icewm"
    read -rp "Enter number (1-6): " de_choice < /dev/tty
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

tag="$([[ $distro == "alpine" && $env == "xfce" ]] && echo "latest" || echo "$distro-$env")"

echo "You selected: $tag"
read -rp "Proceed with installation? [y/N]: " confirm < /dev/tty
[[ "${confirm,,}" != "y" ]] && echo "Installation cancelled." && exit 1

docker pull lscr.io/linuxserver/webtop:$tag

keep=$(docker images -q lscr.io/linuxserver/webtop:$tag)
images=$(docker images --filter=reference='lscr.io/linuxserver/webtop:*' -q | grep -v "$keep")
[ -n "$images" ] && docker rmi $images

docker rm -f desktop || true
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
  --shm-size="$shm_size" \
  --restart unless-stopped \
  lscr.io/linuxserver/webtop:$tag

# Step 6: Install Desktop AppImage
APPNAME="Desktop"
install_dir="/userdata/system/add-ons/${APPNAME,,}"
bin_path="$install_dir/${APPNAME}.AppImage"
mkdir -p "$install_dir" /userdata/roms/ports

case "$arch" in
    x86_64)
        url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/${APPNAME}.AppImage"
        ;;
    aarch64)
        url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/${APPNAME}-arm64.AppImage"
        ;;
    *) echo "Unsupported architecture: $arch. Exiting." && exit 1 ;;
esac

wget -q --show-progress -O "$bin_path" "$url"
chmod +x "$bin_path"

# Step 7: Create launcher
echo "Creating Desktop launcher in Ports..."
cat << EOF > /userdata/roms/ports/BatoDesktop.sh
#!/bin/bash
batocera-mouse show
QT_SCALE_FACTOR="1" GDK_SCALE="1" DISPLAY=:0.0 "$bin_path" --no-sandbox
EOF
chmod +x /userdata/roms/ports/BatoDesktop.sh

# Step 8: Controller config
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

# Step 9: Refresh Ports & add media
curl -s http://127.0.0.1:1234/reloadgames

echo "Adding image and marquee..."
mkdir -p /userdata/roms/ports/images
curl -Ls -o /userdata/roms/ports/images/desktop-logo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/desktop/extra/desktop-logo.png
curl -Ls -o /userdata/roms/ports/images/desktop-marquee.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/desktop/extra/desktop-marquee.png

gamelist_file="/userdata/roms/ports/gamelist.xml"
if [ ! -f "$gamelist_file" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$gamelist_file"
fi

xml_entry="<game>
    <path>/userdata/roms/ports/BatoDesktop.sh</path>
    <name>Desktop</name>
    <image>/userdata/roms/ports/images/desktop-logo.png</image>
    <marquee>/userdata/roms/ports/images/desktop-marquee.png</marquee>
    <command>/userdata/roms/ports/BatoDesktop.sh</command>
</game>"

tmp_file=$(mktemp)
awk -v entry="$xml_entry" '
    /<\/gameList>/ { print entry }
    { print }
' "$gamelist_file" > "$tmp_file" && mv "$tmp_file" "$gamelist_file"

echo "✅ BatoDesktop installed and added to Ports menu!"
sleep 5
