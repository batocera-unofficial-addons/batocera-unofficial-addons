#!/bin/bash

# Variables
APPNAME="JDownloader"
PACKAGE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/jdownloader/extra/jdownloader.tar.gz"
INSTALL_DIR="/userdata/system/add-ons/jdownloader"
ICON_URL="https://upload.wikimedia.org/wikipedia/commons/f/f7/Jdownloader.png"
ICON_PATH="/userdata/system/add-ons/${APPNAME,,}/extra/${APPNAME,,}-icon.png"
DESKTOP_ENTRY="/userdata/system/configs/${APPNAME,,}/${APPNAME,,}.desktop"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
SERVICE_SCRIPT="/userdata/system/services/jdownloader"

mkdir -p "/userdata/system/add-ons/${APPNAME,,}/extra"
mkdir -p "/userdata/system/configs/${APPNAME,,}"
mkdir -p "/userdata/system/services"

echo "[+] Installing JDownloader..."

# === Step 1: Set up Java ===
echo "Installing Java..."
mkdir -p /userdata/system/java
cd /userdata/system/java

# Clean up previous download
rm -f microsoft-jdk-17-linux-x64.tar.gz

echo "Downloading Java JDK 17..."
curl -L -O https://aka.ms/download-jdk/microsoft-jdk-17-linux-x64.tar.gz

echo "Extracting Java..."
tar -xzf microsoft-jdk-17-linux-x64.tar.gz
JDK_DIR=$(find . -maxdepth 1 -type d -name "jdk-17*" | head -n 1)
JDK_PATH="/userdata/system/java/$JDK_DIR"

echo "Java installed at $JDK_PATH"

# === Step 2: Download and extract JDownloader package ===
echo "Downloading JDownloader package..."
mkdir -p "$INSTALL_DIR"
cd /tmp
curl -L -o jdownloader.tar.gz "$PACKAGE_URL"

echo "Extracting JDownloader..."
tar -xzf jdownloader.tar.gz -C /userdata/system/add-ons/
rm -f jdownloader.tar.gz

# Set Java path for JDownloader
export INSTALL4J_JAVA_HOME="$JDK_PATH"
export PATH="$JDK_PATH/bin:$PATH"

# === Step 3: Create service management script ===
create_service_script() {
echo "Creating service management script..."

cat <<EOF > "${SERVICE_SCRIPT}"
#!/bin/bash

JDOWNLOADER_DIR="/userdata/system/add-ons/jdownloader"
LAUNCHER="\${JDOWNLOADER_DIR}/jdownloader-background"
PID_FILE="/var/run/jdownloader.pid"

# Set Java environment
export INSTALL4J_JAVA_HOME="$JDK_PATH"
export PATH="$JDK_PATH/bin:\$PATH"

case "\$1" in
    start)
        if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
            echo "JDownloader is already running"
            exit 0
        fi
        echo "Starting JDownloader in background mode..."
        nohup "\$LAUNCHER" > /dev/null 2>&1 &
        echo \$! > "\$PID_FILE"
        echo "JDownloader started (PID: \$(cat \$PID_FILE))"
        ;;
    stop)
        if [ ! -f "\$PID_FILE" ]; then
            echo "JDownloader is not running"
            exit 0
        fi
        PID=\$(cat "\$PID_FILE")
        if kill -0 "\$PID" 2>/dev/null; then
            echo "Stopping JDownloader (PID: \$PID)..."
            kill "\$PID"
            rm -f "\$PID_FILE"
            echo "JDownloader stopped"
        else
            echo "JDownloader is not running (stale PID file)"
            rm -f "\$PID_FILE"
        fi
        ;;
    restart)
        \$0 stop
        sleep 2
        \$0 start
        ;;
    status)
        if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
            echo "JDownloader is running (PID: \$(cat \$PID_FILE))"
            exit 0
        else
            echo "JDownloader is not running"
            exit 1
        fi
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

chmod +x "${SERVICE_SCRIPT}"
echo "Service script created at ${SERVICE_SCRIPT}"
}

# === Step 4: Create desktop launcher ===
create_launcher() {
echo "Creating desktop launcher..."

# Download icon
curl -L -o "$ICON_PATH" "$ICON_URL"

# Create desktop entry
cat <<EOF > "${DESKTOP_ENTRY}"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APPNAME}
Exec=${INSTALL_DIR}/jdownloader2
Icon=${ICON_PATH}
Terminal=false
Categories=Utility;batocera.linux;
EOF

cp "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/${APPNAME,,}.desktop"
chmod +x "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/${APPNAME,,}.desktop"

# Restore script for .desktop
cat <<EOF > "/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"
#!/bin/bash
if [ ! -f "${DESKTOP_DIR}/${APPNAME,,}.desktop" ]; then
    cp "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/${APPNAME,,}.desktop"
    chmod +x "${DESKTOP_DIR}/${APPNAME,,}.desktop"
fi
EOF
chmod +x "/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"

# Add restore script to custom.sh if not already added
if ! grep -q "jdownloader/restore_desktop_entry.sh" "${CUSTOM_SCRIPT}" 2>/dev/null; then
    echo "\"/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh\" &" >> "${CUSTOM_SCRIPT}"
fi
}

# Run all setup steps
create_service_script
create_launcher

batocera-services enable jdownloader
batocera-services start jdownloader

echo ""
echo "========================================="
echo "  Installation Complete!"
echo "========================================="
echo "JDownloader installed successfully!"
echo ""
echo "You can:"
echo "  - Launch JDownloader from the applications menu"
echo "  - Manage background service:"
echo "    /userdata/system/services/jdownloader start|stop|restart|status"
echo ""
