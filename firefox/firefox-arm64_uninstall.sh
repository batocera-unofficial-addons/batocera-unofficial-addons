#!/bin/bash
# Firefox uninstaller for Batocera (ARM64). Removes Firefox and its profile, the Ports
# launcher and its gamelist entry, the desktop entry and the custom.sh line that restores it.
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/firefox/firefox-arm64_uninstall.sh | bash

# Same names and values as firefox-arm64.sh
APPNAME="Firefox"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
RESTORE_SCRIPT="/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"
CUSTOM_STARTUP="/userdata/system/custom.sh"

main() {
    echo "========================================="
    echo "Uninstalling: ${APPNAME}"
    echo "========================================="
    echo ""

    echo "Stopping ${APPNAME}..."
    # The launcher starts it as ./firefox; its child processes run by full path
    pkill -x "${APPNAME,,}" 2>/dev/null
    pkill -f "/userdata/system/add-ons/${APPNAME,,}/" 2>/dev/null

    # Remove the startup line before the script it points at
    if [ -f "${CUSTOM_STARTUP}" ]; then
        echo "Removing ${APPNAME} entry from custom.sh"
        sed -i "\|${RESTORE_SCRIPT}|d" "${CUSTOM_STARTUP}"
    fi

    echo "Removing desktop entry"
    rm -f "${DESKTOP_FILE}" "${PERSISTENT_DESKTOP}" "${RESTORE_SCRIPT}"
    rm -rf "/userdata/system/configs/${APPNAME,,}"

    # The launcher sets HOME to this directory, so the Firefox profile is in it too
    echo "Removing /userdata/system/add-ons/${APPNAME,,}"
    rm -rf "/userdata/system/add-ons/${APPNAME,,}"

    echo "Removing Ports launcher and logo"
    rm -f /userdata/roms/ports/Firefox.sh /userdata/roms/ports/images/firefox-logo.png
    rm -f /tmp/firefox-es.log

    if [ -f /userdata/roms/ports/gamelist.xml ]; then
        echo "Removing ${APPNAME} entry from gamelist.xml"
        xmlstarlet ed -d "/gameList/game[path='./Firefox.sh']" /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml
        rm -f /userdata/roms/ports/gamelist.xml.tmp
    fi

    echo "Refreshing Ports menu..."
    curl -s http://127.0.0.1:1234/reloadgames

    echo ""
    echo "========================================="
    echo "Uninstallation complete: ${APPNAME}"
    echo "========================================="
}

main "$@"
