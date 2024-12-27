#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/stremio/Stremio+4.4.20.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Prepare directories
echo "Setting up directories..."
mkdir -p /userdata/system/add-ons/stremio
mkdir -p /userdata/system/add-ons/stremio/stremio-config
mkdir -p /userdata/system/logs
mkdir -p /userdata/roms/ports/images

# Step 3: Download the AppImage
echo "Downloading Stremio AppImage..."
wget -q --show-progress -O /userdata/system/add-ons/stremio/Stremio.AppImage "$appimage_url"
if [ $? -ne 0 ]; then
    echo "Failed to download Stremio AppImage. Exiting."
    exit 1
fi

chmod a+x /userdata/system/add-ons/stremio/Stremio.AppImage
echo "Stremio AppImage downloaded and marked as executable."

# Step 4: Create the Stremio launch script
echo "Creating Stremio launch script in Ports..."
cat << 'EOF' > /userdata/roms/ports/Stremio.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0
export NSS_DB="/userdata/system/add-ons/stremio/stremio/.pki/nssdb"
export LD_LIBRARY_PATH="/userdata/system/add-ons/stremio/lib:$LD_LIBRARY_PATH"
export STREMIO_LOCALFILES_DIR="/userdata/system/add-ons/stremio/stremio-config"
export HOME="/userdata/system/add-ons/stremio"

# Create necessary directories
mkdir -p "${NSS_DB}"
mkdir -p /userdata/system/add-ons/stremio/.stremio-server/localFiles
mkdir -p "${STREMIO_LOCALFILES_DIR}"
mkdir -p "${HOME}/.pki/nssdb"

# Initialize NSS database
if [ ! -f "${NSS_DB}/cert9.db" ]; then
    echo "Initializing NSS database at ${NSS_DB}..."
    certutil -d sql:"${NSS_DB}" -N --empty-password
fi

# Function to kill processes occupying specific ports
kill_process_on_port() {
    port=$1
    pid=$(lsof -ti :$port)
    if [ -n "$pid" ]; then
        echo "Process using port $port found with PID $pid. Killing process..."
        sudo kill -9 $pid
    else
        echo "No process found using port $port."
    fi
}

# Ports to check for conflicts
PORTS=("11470" "12470" "11471" "11472")

# Check and kill processes occupying the ports
for port in "${PORTS[@]}"; do
    kill_process_on_port $port
done

# Directories and file paths
app_dir="/userdata/system/add-ons/stremio"
config_dir="${app_dir}/stremio-config"
config_symlink="${HOME}/.config/stremio"
app_image="${app_dir}/Stremio.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/stremio.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Stremio"

# Create persistent directory for Stremio config
mkdir -p "${config_dir}"

# Move existing config if present
if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
    mv "${config_symlink}" "${config_dir}"
fi

# Ensure config directory is symlinked
if [ ! -L "${config_symlink}" ]; then
    ln -sf "${config_dir}" "${config_symlink}"
fi

# Check if the AppImage exists and is executable
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Stremio.AppImage --no-sandbox --local-files-dir="${STREMIO_LOCALFILES_DIR}" > "${log_file}" 2>&1
    echo
else
    echo "Error: Stremio.AppImage not found or not executable at ${app_image}"
fi
EOF

chmod +x /userdata/roms/ports/Stremio.sh

# Step 5: Add Stremio to Ports menu
if ! command -v xmlstarlet &> /dev/null; then
    echo "Error: xmlstarlet is not installed. Install it and re-run the script."
    exit 1
fi

echo "Adding Stremio to Ports menu..."
curl -L -o /userdata/roms/ports/images/stremiologo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/stremio/extra/stremiologo.png
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Stremio.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Stremio" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/stremiologo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

# Step 6: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Stremio from the Ports menu."
