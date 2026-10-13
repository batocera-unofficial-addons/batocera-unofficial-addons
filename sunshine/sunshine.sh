#!/bin/bash

# Step 1: Install Sunshine
echo "Installing Sunshine..."

# Create target directory
mkdir -p /userdata/system/add-ons/sunshine

# Fetch latest AppImage URL and download it
# Releases carry one AppImage per architecture, so pick the one for this machine
APPIMAGE_URL=$(curl -s https://api.github.com/repos/LizardByte/Sunshine/releases/latest | grep browser_download_url | grep AppImage | cut -d '"' -f 4 | grep "$(uname -m)" | head -n 1)

if [ -n "$APPIMAGE_URL" ]; then
    # Download next to the old copy and only swap it in once the download succeeded
    if curl -fL "$APPIMAGE_URL" -o /userdata/system/add-ons/sunshine/sunshine.AppImage.new; then
        [ -f /userdata/system/services/sunshine ] && batocera-services stop sunshine
        mv -f /userdata/system/add-ons/sunshine/sunshine.AppImage.new /userdata/system/add-ons/sunshine/sunshine.AppImage
        chmod +x /userdata/system/add-ons/sunshine/sunshine.AppImage
        echo "Sunshine installed successfully."
    else
        rm -f /userdata/system/add-ons/sunshine/sunshine.AppImage.new
        echo "Failed to download the Sunshine AppImage."
        exit 1
    fi
else
    echo "Failed to fetch the latest Sunshine AppImage URL."
    exit 1
fi

# Sunshine links against libwayland-client, which Batocera's x86_64 image does not ship.
# Keep a private copy next to the AppImage so the service does not depend on boot order.
mkdir -p /userdata/system/add-ons/sunshine/lib
SYSTEM_WAYLAND=$(readlink -f /usr/lib/libwayland-client.so.0 2>/dev/null)
if [ -f "$SYSTEM_WAYLAND" ] && [ "${SYSTEM_WAYLAND#/userdata/}" = "$SYSTEM_WAYLAND" ]; then
    # This Batocera build has its own copy; don't shadow it
    rm -f /userdata/system/add-ons/sunshine/lib/libwayland-client.so.0
elif [ -f /userdata/system/add-ons/.dep/libwayland-client.so.0 ]; then
    rm -f /userdata/system/add-ons/sunshine/lib/libwayland-client.so.0
    cp -fL /userdata/system/add-ons/.dep/libwayland-client.so.0 /userdata/system/add-ons/sunshine/lib/libwayland-client.so.0
else
    curl -fL https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/.dep/libwayland-client.so.0 -o /userdata/system/add-ons/sunshine/lib/libwayland-client.so.0 || echo "Failed to download libwayland-client.so.0, Sunshine may not start."
fi

# Create a persistent configuration directory
mkdir -p /userdata/system/logs

# Configure Sunshine as a service
echo "Configuring Sunshine service..."
mkdir -p /userdata/system/services
cat << 'EOF' > /userdata/system/services/sunshine
#!/bin/bash
#
# sunshine service script for Batocera
# Functional start/stop/restart/status/uninstall

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME=/userdata/system/add-ons/sunshine

# Directories and file paths
app_dir="/userdata/system/add-ons/sunshine"
app_image="${app_dir}/sunshine.AppImage"
conf_file="${app_dir}/.config/sunshine/sunshine.conf"
sunshine_log="${app_dir}/.config/sunshine/sunshine.log"
log_dir="/userdata/system/logs"
log_file="${log_dir}/sunshine.log"
pid_file="/var/run/sunshine-supervisor.pid"
hevc_marker="${app_dir}/.hevc_fallback_applied"

# Private libraries placed by the installer (libwayland-client)
export LD_LIBRARY_PATH="${app_dir}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Batocera keeps its VA-API drivers in /usr/lib/va, which is not where the
# AppImage's libva looks. Without this Sunshine falls back to software encoding.
if [ -z "$LIBVA_DRIVERS_PATH" ] && [ -d /usr/lib/va ]; then
    export LIBVA_DRIVERS_PATH=/usr/lib/va
fi

# Ensure log directory exists
mkdir -p "${log_dir}"

supervisor_running() {
    [ -f "${pid_file}" ] && kill -0 "$(cat "${pid_file}")" 2>/dev/null
}

# On some GPUs Sunshine's HEVC hardware encoder aborts on the first frame of a
# stream. If Sunshine died within seconds of creating an HEVC encoder for a
# connected client, turn HEVC off so clients fall back to H.264.
# This happens at most once per install and never when hevc_mode is already set,
# so the owner can turn HEVC back on and it will stay on.
# $1 = number of lines the service log had before this run of Sunshine
hevc_fallback() {
    local run_log connect_line encoder_line stamp created
    [ -e "${hevc_marker}" ] && return 1
    grep -q '^hevc_mode' "${conf_file}" 2>/dev/null && return 1

    run_log=$(tail -n "+$(( $1 + 1 ))" "${log_file}" 2>/dev/null)
    connect_line=$(echo "$run_log" | grep -n 'CLIENT CONNECTED' | tail -n 1 | cut -d: -f1)
    [ -n "$connect_line" ] || return 1
    encoder_line=$(echo "$run_log" | tail -n "+${connect_line}" | grep 'Creating encoder \[' | tail -n 1)
    case "$encoder_line" in
        *'Creating encoder [hevc_'*) ;;
        *) return 1 ;;
    esac
    stamp=$(echo "$encoder_line" | sed -n 's/^\[\([0-9-]* [0-9:]*\)\..*/\1/p')
    created=$(date -d "$stamp" +%s 2>/dev/null) || return 1
    [ $(( $(date +%s) - created )) -le 30 ] || return 1

    mkdir -p "$(dirname "${conf_file}")"
    [ -s "${conf_file}" ] && [ -n "$(tail -c 1 "${conf_file}")" ] && echo >> "${conf_file}"
    echo "hevc_mode = 1" >> "${conf_file}"
    touch "${hevc_marker}"
    echo "$(date): Sunshine crashed right after starting an HEVC stream. HEVC has been turned off (hevc_mode = 1 in ${conf_file}) so clients use H.264. To turn it back on, set HEVC support in the Web UI or remove that line; this will not be changed again."
}

# Sunshine renames its previous logs to sunshine.log.1 ... sunshine.log.5 on
# every start and has no setting for how many to keep. Trim them before each
# start so that only the wanted number of old logs is left afterwards.
# Default is 2; change it with: batocera-settings-set sunshine.log_keep <0-5>
prune_logs() {
    local keep file number
    keep=$(batocera-settings-get sunshine.log_keep 2>/dev/null)
    case "$keep" in
        ''|*[!0-9]*) keep=2 ;;
    esac
    [ "$keep" -eq 0 ] && rm -f "${sunshine_log}"
    for file in "${sunshine_log}".*; do
        number="${file##*.}"
        case "$number" in
            ''|*[!0-9]*) continue ;;
        esac
        [ "$number" -ge "$keep" ] && rm -f "$file"
    done
}

# The web UI rejects browsers that reach it under a name or address Sunshine
# does not know (CSRF protection). Collect every address and name this machine
# answers to and merge them into csrf_allowed_origins, keeping existing entries.
update_csrf_origins() {
    local hosts="localhost 127.0.0.1" host ip name ts dns current entry origins=""

    for ip in $(ip -o -4 addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | grep -v '^127\.'); do
        hosts="${hosts} ${ip}"
        # The name DNS gives this address (router DNS, Tailscale MagicDNS, ...)
        name=$(timeout 2 python3 -c 'import socket,sys; print(socket.gethostbyaddr(sys.argv[1])[0])' "$ip" 2>/dev/null)
        hosts="${hosts} ${name} ${name%%.*}"
    done

    host=$(hostname 2>/dev/null)
    [ -n "$host" ] && hosts="${hosts} ${host} ${host}.local"

    # Tailscale name, with and without the tailnet domain
    for ts in tailscale /userdata/system/add-ons/tailscale/tailscale /userdata/tailscale/tailscale; do
        command -v "$ts" > /dev/null 2>&1 || continue
        dns=$(timeout 5 "$ts" status --json 2>/dev/null | grep -m1 '"DNSName"' | cut -d '"' -f 4)
        dns="${dns%.}"
        hosts="${hosts} ${dns} ${dns%%.*}"
        break
    done

    current=$(grep -m1 '^csrf_allowed_origins' "${conf_file}" 2>/dev/null | cut -d= -f2-)
    for entry in $(echo "$current" | tr ',' ' ') $(for name in $hosts; do echo "https://${name}"; done | tr 'A-Z' 'a-z'); do
        case ",${origins}," in
            *",${entry},"*) ;;
            *) origins="${origins:+${origins},}${entry}" ;;
        esac
    done
    [ -n "$origins" ] || return 0
    grep -qxF "csrf_allowed_origins = ${origins}" "${conf_file}" 2>/dev/null && return 0

    mkdir -p "$(dirname "${conf_file}")"
    if grep -q '^csrf_allowed_origins' "${conf_file}" 2>/dev/null; then
        sed -i "s|^csrf_allowed_origins.*|csrf_allowed_origins = ${origins}|" "${conf_file}"
    else
        # Make sure we start on a new line
        [ -s "${conf_file}" ] && [ -n "$(tail -c 1 "${conf_file}")" ] && echo >> "${conf_file}"
        echo "csrf_allowed_origins = ${origins}" >> "${conf_file}"
    fi
}


# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): ${1} service sunshine"

case "$1" in
    start)
        echo "Starting Sunshine service..."

        if supervisor_running; then
            echo "Sunshine is already running."
            exit 0
        fi

        # Start Sunshine AppImage
        if [ -x "${app_image}" ]; then
            cd "${app_dir}"
            update_csrf_origins
            : > "${log_file}"
            # Run Sunshine under a small supervisor so a crash does not leave it dead
            (
                crashes=0
                while true; do
                    started=$(date +%s)
                    log_lines=$(wc -l < "${log_file}")
                    prune_logs
                    ./sunshine.AppImage
                    rc=$?
                    # A clean exit means Sunshine was asked to quit
                    [ "$rc" -eq 0 ] && break
                    hevc_fallback "$log_lines"
                    # Only crashes in quick succession count towards giving up
                    [ $(( $(date +%s) - started )) -ge 60 ] && crashes=0
                    crashes=$((crashes + 1))
                    if [ "$crashes" -ge 5 ]; then
                        echo "$(date): Sunshine crashed ${crashes} times in a row (exit code ${rc}), giving up."
                        break
                    fi
                    echo "$(date): Sunshine exited with code ${rc}, restarting..."
                    sleep 3
                done
                rm -f "${pid_file}"
            ) >> "${log_file}" 2>&1 &
            echo $! > "${pid_file}"
            echo "Sunshine started successfully."
        else
            echo "Sunshine.AppImage not found or not executable."
            exit 1
        fi
        ;;
    stop)
        echo "Stopping Sunshine service..."
        # Stop the supervisor first so it does not restart Sunshine
        if supervisor_running; then
            kill "$(cat "${pid_file}")" 2>/dev/null
        fi
        rm -f "${pid_file}"
        # Stop the specific processes for sunshine.AppImage
        pkill -f "./sunshine.AppImage" && echo "Sunshine stopped." || echo "Sunshine is not running."
        pkill -f "/tmp/.mount_sunshi" && echo "Sunshine child process stopped." || echo "Sunshine child process is not running."
        ;;
restart)
    "$0" stop
    "$0" start
    ;;
    status)
        if pgrep -f "sunshine.AppImage" > /dev/null; then
            echo "Sunshine is running."
            exit 0
        else
            echo "Sunshine is stopped."
            exit 1
        fi
        ;;
    uninstall)
        echo "Uninstalling Sunshine service..."
        "$0" stop
        rm -f "${app_image}"
        echo "Sunshine uninstalled successfully."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|uninstall}"
        exit 1
        ;;
esac

exit $?

EOF

chmod +x /userdata/system/services/sunshine

echo "Applying Nvidia patches for a smoother experience..."
# Apply Nvidia patches if necessary
curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/nvidiapatch/nvidiapatch.sh | bash

# Enable and start the Sunshine service
batocera-services enable sunshine
batocera-services start sunshine


echo
dialog --msgbox "Installation complete!\n\nPlease head to https://YOUR-MACHINE-IP:47990 to pair Sunshine with Moonlight if this is your first time running Sunshine :)" 10 60
