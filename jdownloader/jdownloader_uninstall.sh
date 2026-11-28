#!/bin/bash
# Uninstaller for JDownloader, installed by jdownloader.sh.
# Stops and disables the jdownloader service and removes it, the F1
# Applications entry and its saved copy, the boot restore script and its
# custom.sh line, and the add-on folder with its own Java runtime.
# Kept: JDownloader settings (jd2/cfg) and downloaded files.

SERVICE_NAME="jdownloader"
SERVICE_SCRIPT="/userdata/system/services/${SERVICE_NAME}"
INSTALL_DIR="/userdata/system/add-ons/jdownloader"
CFG_DIR="${INSTALL_DIR}/jd2/cfg"
CONFIG_DIR="/userdata/system/configs/jdownloader"
DESKTOP_FILE="/usr/share/applications/jdownloader.desktop"
RESTORE_SCRIPT="${CONFIG_DIR}/restore_desktop_entry.sh"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
LEGACY_JAVA_DIR="/userdata/system/java"
DOWNLOADS_DIR="/userdata/system/Downloads"

remove_file() {
    if [ -f "$1" ]; then
        echo "Removing: $1"
        rm -f "$1"
    fi
}

main() {
    echo "========================================="
    echo "Uninstalling: JDownloader"
    echo "========================================="
    echo ""

    if [ -f "$SERVICE_SCRIPT" ]; then
        echo "Stopping and disabling the ${SERVICE_NAME} service..."
        batocera-services stop "$SERVICE_NAME" >/dev/null 2>&1
        batocera-services disable "$SERVICE_NAME" >/dev/null 2>&1
    fi
    # JDownloader started from F1 > Applications, or by an older service
    # (it runs as "java -jar JDownloader.jar" from jd2)
    pkill -f "java .*-jar JDownloader.jar" >/dev/null 2>&1
    rm -f /var/run/jdownloader.pid
    remove_file "$SERVICE_SCRIPT"

    if [ -f "$CUSTOM_SCRIPT" ] && grep -qF "$RESTORE_SCRIPT" "$CUSTOM_SCRIPT"; then
        echo "Removing the restore line from ${CUSTOM_SCRIPT}"
        sed -i "\|${RESTORE_SCRIPT}|d" "$CUSTOM_SCRIPT"
    fi
    remove_file "$DESKTOP_FILE"
    remove_file "${CONFIG_DIR}/jdownloader.desktop"
    remove_file "$RESTORE_SCRIPT"
    rmdir "$CONFIG_DIR" 2>/dev/null

    # Everything in the add-on folder except the settings in jd2/cfg
    if [ -d "$INSTALL_DIR" ]; then
        echo "Removing: ${INSTALL_DIR} (except jd2/cfg)"
        find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name jd2 -exec rm -rf {} +
        if [ -d "${INSTALL_DIR}/jd2" ]; then
            find "${INSTALL_DIR}/jd2" -mindepth 1 -maxdepth 1 ! -name cfg -exec rm -rf {} +
        fi
        rmdir "${INSTALL_DIR}/jd2" "$INSTALL_DIR" 2>/dev/null
    fi

    # Older installers downloaded Java into the shared /userdata/system/java.
    # Remove the leftover download; the JDK itself is left in case something
    # else uses it.
    remove_file "${LEGACY_JAVA_DIR}/microsoft-jdk-17-linux-x64.tar.gz"
    LEGACY_JDK=$(find "$LEGACY_JAVA_DIR" -mindepth 1 -maxdepth 1 -type d -name "jdk-17*" 2>/dev/null | head -n 1)

    echo ""
    if [ -d "$CFG_DIR" ]; then
        echo "JDownloader settings were kept in ${CFG_DIR}."
    fi
    if [ -d "$DOWNLOADS_DIR" ]; then
        echo "Downloaded files were kept in ${DOWNLOADS_DIR}."
    fi
    if [ -n "$LEGACY_JDK" ]; then
        echo "An older install put Java in ${LEGACY_JDK}. It was kept;"
        echo "delete it by hand if nothing else uses it."
    fi
    echo ""
    echo "========================================="
    echo "Uninstallation complete: JDownloader"
    echo "========================================="
}

main "$@"
