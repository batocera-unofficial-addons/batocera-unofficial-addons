#!/bin/bash
# BUA Installer: JDownloader 2
# Installs JDownloader with its own Java 17 runtime, an F1 Applications entry
# and the "jdownloader" background service. On a reinstall the JDownloader
# settings in jd2/cfg (accounts, My.JDownloader login, download list) are kept.

# Variables
APPNAME="JDownloader"
PACKAGE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/jdownloader/extra/jdownloader.tar.gz"
JDK_URL="https://aka.ms/download-jdk/microsoft-jdk-17-linux-x64.tar.gz"
ADDONS_DIR="/userdata/system/add-ons"
INSTALL_DIR="${ADDONS_DIR}/jdownloader"
JD_DIR="${INSTALL_DIR}/jd2"
JAVA_DIR="${INSTALL_DIR}/java"
TEMP_DIR="/userdata/tmp/jdownloader"
ICON_URL="https://upload.wikimedia.org/wikipedia/commons/f/f7/Jdownloader.png"
ICON_PATH="${INSTALL_DIR}/extra/jdownloader-icon.png"
CONFIG_DIR="/userdata/system/configs/jdownloader"
DESKTOP_ENTRY="${CONFIG_DIR}/jdownloader.desktop"
DESKTOP_DIR="/usr/share/applications"
RESTORE_SCRIPT="${CONFIG_DIR}/restore_desktop_entry.sh"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
SERVICE_NAME="jdownloader"
SERVICE_SCRIPT="/userdata/system/services/${SERVICE_NAME}"

error_exit() {
    echo "Error: $1" >&2
    rm -rf "${TEMP_DIR:?}"
    exit 1
}

if [ "$(uname -m)" != "x86_64" ]; then
    dialog --title "$APPNAME" --msgbox "${APPNAME} is only available for x86_64." 8 60
    exit 1
fi

echo "[+] Installing ${APPNAME}..."

mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "/userdata/system/services" "$TEMP_DIR"

# Stop a running service from an earlier install before replacing its files
if [ -x "$SERVICE_SCRIPT" ]; then
    batocera-services stop "$SERVICE_NAME" >/dev/null 2>&1
fi

# === Step 1: Java 17 (kept inside the add-on folder, used only by JDownloader) ===
JDK_PATH=$(find "$JAVA_DIR" -mindepth 1 -maxdepth 1 -type d -name "jdk-17*" 2>/dev/null | head -n 1)
if [ -n "$JDK_PATH" ] && [ -x "${JDK_PATH}/bin/java" ]; then
    echo "Java already installed at ${JDK_PATH}"
else
    echo "Downloading Java JDK 17..."
    curl -fL -o "${TEMP_DIR}/jdk.tar.gz" "$JDK_URL" || error_exit "Failed to download Java."
    echo "Extracting Java..."
    mkdir -p "$JAVA_DIR"
    tar -xzf "${TEMP_DIR}/jdk.tar.gz" -C "$JAVA_DIR" || error_exit "Failed to extract Java."
    JDK_PATH=$(find "$JAVA_DIR" -mindepth 1 -maxdepth 1 -type d -name "jdk-17*" | head -n 1)
    [ -n "$JDK_PATH" ] && [ -x "${JDK_PATH}/bin/java" ] || error_exit "Java not found after extraction."
    echo "Java installed at ${JDK_PATH}"
fi

# === Step 2: Download and extract JDownloader package ===
echo "Downloading ${APPNAME} package..."
curl -fL -o "${TEMP_DIR}/jdownloader.tar.gz" "$PACKAGE_URL" || error_exit "Failed to download ${APPNAME}."

# Keep the user's settings: the package ships its own jd2/cfg
if [ -d "${JD_DIR}/cfg" ]; then
    echo "Keeping existing ${APPNAME} settings..."
    mv "${JD_DIR}/cfg" "${TEMP_DIR}/cfg"
fi

echo "Extracting ${APPNAME}..."
tar -xzf "${TEMP_DIR}/jdownloader.tar.gz" -C "$ADDONS_DIR" || error_exit "Failed to extract ${APPNAME}."

if [ -d "${TEMP_DIR}/cfg" ]; then
    rm -rf "${JD_DIR:?}/cfg"
    mv "${TEMP_DIR}/cfg" "${JD_DIR}/cfg"
fi
rm -rf "${TEMP_DIR:?}"

# === Step 3: Launchers using this Java (the package's copies point at a fixed JDK version) ===
cat <<EOF > "${INSTALL_DIR}/jdownloader2"
#!/bin/bash
# JDownloader with its window
export INSTALL4J_JAVA_HOME="${JDK_PATH}"
export PATH="${JDK_PATH}/bin:\$PATH"
cd "${JD_DIR}" || exit 1
DISPLAY=\${DISPLAY:-:0.0} exec java -jar JDownloader.jar
EOF

cat <<EOF > "${INSTALL_DIR}/jdownloader2-background"
#!/bin/bash
# JDownloader headless, in the foreground (the service puts it in the background)
export INSTALL4J_JAVA_HOME="${JDK_PATH}"
export PATH="${JDK_PATH}/bin:\$PATH"
cd "${JD_DIR}" || exit 1
exec java -Djava.awt.headless=true -jar JDownloader.jar -norestart
EOF
chmod a+x "${INSTALL_DIR}/jdownloader2" "${INSTALL_DIR}/jdownloader2-background"

# === Step 4: Service script ===
echo "Creating service script..."
cat <<'EOF' > "$SERVICE_SCRIPT"
#!/bin/bash
# JDownloader background service for Batocera (BUA)

LAUNCHER="/userdata/system/add-ons/jdownloader/jdownloader2-background"
LOG_FILE="/userdata/system/add-ons/jdownloader/jd2/jd.log"
PID_FILE="/var/run/jdownloader.pid"

is_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

case "$1" in
    start)
        if is_running; then
            echo "JDownloader is already running"
            exit 0
        fi
        if [ ! -x "$LAUNCHER" ]; then
            echo "JDownloader launcher not found: $LAUNCHER"
            exit 1
        fi
        echo "Starting JDownloader in background mode..."
        nohup "$LAUNCHER" > "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        echo "JDownloader started (PID: $(cat "$PID_FILE"))"
        ;;
    stop)
        if ! is_running; then
            echo "JDownloader is not running"
            rm -f "$PID_FILE"
            exit 0
        fi
        PID=$(cat "$PID_FILE")
        echo "Stopping JDownloader (PID: $PID)..."
        kill "$PID"
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            kill -0 "$PID" 2>/dev/null || break
            sleep 1
        done
        kill -0 "$PID" 2>/dev/null && kill -9 "$PID"
        rm -f "$PID_FILE"
        echo "JDownloader stopped"
        ;;
    restart)
        "$0" stop
        sleep 2
        "$0" start
        ;;
    status)
        if is_running; then
            echo "JDownloader is running (PID: $(cat "$PID_FILE"))"
            exit 0
        else
            echo "JDownloader is not running"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
chmod a+x "$SERVICE_SCRIPT"
echo "Service script created at ${SERVICE_SCRIPT}"

# === Step 5: Desktop launcher (F1 Applications) ===
echo "Creating desktop launcher..."
mkdir -p "$(dirname "$ICON_PATH")"
curl -fL -o "$ICON_PATH" "$ICON_URL" || echo "Warning: could not download the icon, using the packaged one."

cat <<EOF > "$DESKTOP_ENTRY"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APPNAME}
Exec=${INSTALL_DIR}/jdownloader2
Icon=${ICON_PATH}
Terminal=false
Categories=Utility;batocera.linux;
EOF
chmod a+x "$DESKTOP_ENTRY"
cp "$DESKTOP_ENTRY" "${DESKTOP_DIR}/jdownloader.desktop"
chmod a+x "${DESKTOP_DIR}/jdownloader.desktop"

# Restore the desktop entry at boot (/usr/share/applications is not persistent)
cat <<EOF > "$RESTORE_SCRIPT"
#!/bin/bash
if [ ! -f "${DESKTOP_DIR}/jdownloader.desktop" ]; then
    cp "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/jdownloader.desktop"
    chmod a+x "${DESKTOP_DIR}/jdownloader.desktop"
fi
EOF
chmod a+x "$RESTORE_SCRIPT"

[ -f "$CUSTOM_SCRIPT" ] || echo "#!/bin/bash" > "$CUSTOM_SCRIPT"
if ! grep -qF "$RESTORE_SCRIPT" "$CUSTOM_SCRIPT"; then
    echo "\"${RESTORE_SCRIPT}\" &" >> "$CUSTOM_SCRIPT"
fi
chmod a+x "$CUSTOM_SCRIPT"

# === Step 6: Enable and start the service ===
batocera-services enable "$SERVICE_NAME"
batocera-services start "$SERVICE_NAME"

echo ""
echo "========================================="
echo "  Installation Complete!"
echo "========================================="
echo "${APPNAME} installed successfully!"
echo ""
echo "You can:"
echo "  - Launch ${APPNAME} from F1 > Applications"
echo "  - Manage the background service:"
echo "    batocera-services start|stop ${SERVICE_NAME}"
echo "    ${SERVICE_SCRIPT} start|stop|restart|status"
echo ""
