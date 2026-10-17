#!/bin/bash
# Uninstaller for BUA itself, installed by install_x86_new.sh or
# install_arm64_new.sh (through install.batoaddons.app) and the BUA app.
# Removes the symlink manager service and its links, the shared .dep files,
# the bua command, the Ports launcher with its images and gamelist entry,
# the desktop entry, BUA's custom.sh lines, the Python hook, the
# custom_service_handler service and the BUA app's settings files.
#
# It doesn't remove add-ons. "bua uninstall" removes them first; when any are
# still installed, this script names them and asks before going on.
#
#   curl -L <url> | bash
#   curl -L <url> | bash -s -- --ignore-warning   (yes to every question)

ADDONS_DIR="/userdata/system/add-ons"
DOWNLOAD_DIR="/userdata/system/services"
SCRIPT_WITHOUT_EXTENSION="${DOWNLOAD_DIR}/symlink_manager"
CUSTOM_SERVICE_HANDLER="${DOWNLOAD_DIR}/custom_service_handler"
DEP_DIR="${ADDONS_DIR}/.dep"
XMLSTARLET_DEST="${DEP_DIR}/xmlstarlet"
BUA_CLI_DEST="${ADDONS_DIR}/bua/bin/bua"
HISTORY_FILE="${ADDONS_DIR}/bua_history.json"

ROM_PORTS_DIR="/userdata/roms/ports"
BATOCERA_ADDONS_PATH="${ROM_PORTS_DIR}/bua.sh"
PORTS_IMAGES_DIR="${ROM_PORTS_DIR}/images"
BATOCERA_ADDONS_LOGO_DEST="${PORTS_IMAGES_DIR}/BatoceraUnofficialAddons.png"
BATOCERA_ADDONS_WHEEL_DEST="${PORTS_IMAGES_DIR}/BatoceraUnofficialAddons_Wheel.png"
GAMELIST_XML="${ROM_PORTS_DIR}/gamelist.xml"

APPNAME="BUA"
APPNAME_LC="${APPNAME,,}"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
RESTORE_SCRIPT="/userdata/system/configs/${APPNAME_LC}/restore_desktop_entry.sh"
CUSTOM_STARTUP="/userdata/system/custom.sh"

# The lines the BUA installers add to custom.sh (x86, then ARM)
CUSTOM_LINES=(
    "bash \"${RESTORE_SCRIPT}\" &"
    "modprobe fuse &"
)

ignore_warning=false   # set to true by --ignore-warning in main

# Asks a yes/no question in the BUA app, or in the terminal. Returns 0 for
# Yes, 1 for No, a timeout, or no terminal at all. With --ignore-warning,
# every question is answered yes without asking.
ask() {
    local title="$1" text="$2"
    [ "${ignore_warning}" = "true" ] && return 0
    dialog --title "${title}" --clear --timeout 60 --yesno "${text}" 0 0
}

# Add-ons still on the device: successful installs in the BUA app's history,
# then folders in add-ons, one name per line. History names come first so they
# win over a folder of the same name when the list is deduplicated.
remaining_addons() {
    if [ -f "${HISTORY_FILE}" ]; then
        jq -r 'to_entries[] | select(any(.value[]; .success)) | .key' "${HISTORY_FILE}" 2>/dev/null
    fi
    local dir
    for dir in "${ADDONS_DIR}"/*/; do
        [ -d "${dir}" ] || continue
        dir="$(basename "${dir}")"
        [ "${dir}" = "${APPNAME_LC}" ] && continue
        echo "${dir}"
    done
}

# custom.sh without BUA's own lines, blank lines and comments
other_custom_lines() {
    [ -f "${CUSTOM_STARTUP}" ] || return 0
    local line own
    while IFS= read -r line; do
        [[ -z "${line//[[:space:]]/}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        for own in "${CUSTOM_LINES[@]}"; do
            [ "${line}" = "${own}" ] && continue 2
        done
        echo "${line}"
    done < "${CUSTOM_STARTUP}"
}

# Removes a link only when it points at the given file
remove_link() {
    local link="$1" target="$2"
    if [ -L "${link}" ] && [ "$(readlink "${link}")" = "${target}" ]; then
        rm -f "${link}"
    fi
}

main() {
    local arg
    for arg in "$@"; do
        case "${arg}" in
            --ignore-warning) ignore_warning=true ;;
            *)
                echo "Usage: uninstall.sh [--ignore-warning]"
                exit 2
                ;;
        esac
    done

    # Every add-on relies on BUA's symlink manager and .dep files.
    local addons
    addons="$(remaining_addons | sort -fsu)"
    if [ -n "${addons}" ]; then
        local text="These add-ons are still installed:\n\n${addons//$'\n'/\\n}\n\nThey rely on BUA's shared files and services and may stop working. Remove BUA anyway?"
        echo -e "${text}"
        if ! ask "Remove BUA" "${text}"; then
            echo "BUA was not uninstalled."
            exit 1
        fi
        echo "Removing BUA anyway."
    fi

    # On Batocera 43 and later, custom.sh runs at boot through BUA's
    # custom_service_handler. Ask before removing it while custom.sh has
    # lines that aren't BUA's.
    local remove_handler=true
    local version others
    version="$(batocera-version 2>/dev/null | grep -oP '^\d+')"
    others="$(other_custom_lines)"
    if [ -f "${CUSTOM_SERVICE_HANDLER}" ] && [ -n "${others}" ] && [ "${version:-0}" -ge 43 ]; then
        local text="custom.sh runs at boot through BUA's custom_service_handler. It still has these lines:\n\n${others//$'\n'/\\n}\n\nWithout the handler they no longer run at boot. Remove the handler?"
        echo -e "${text}"
        if ask "custom_service_handler" "${text}"; then
            echo "Removing custom_service_handler anyway."
        else
            remove_handler=false
            echo "Keeping custom_service_handler for custom.sh."
        fi
    fi

    echo "Removing BUA..."

    # The gamelist entry first, while BUA's xmlstarlet is still there
    if [ -f "${GAMELIST_XML}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./bua.sh']" "${GAMELIST_XML}" > "${GAMELIST_XML}.tmp" \
            && mv "${GAMELIST_XML}.tmp" "${GAMELIST_XML}"
        rm -f "${GAMELIST_XML}.tmp"
    fi

    # Stop the watch loop first so it can't recreate links, then let the
    # service's stop action remove the links it made into /usr/bin and /usr/lib.
    if [ -f "${SCRIPT_WITHOUT_EXTENSION}" ]; then
        pkill -f "${SCRIPT_WITHOUT_EXTENSION} start"
        batocera-services stop symlink_manager >/dev/null 2>&1
        bash "${SCRIPT_WITHOUT_EXTENSION}" stop >/dev/null 2>&1
        batocera-services disable symlink_manager >/dev/null 2>&1
        rm -f "${SCRIPT_WITHOUT_EXTENSION}"
    fi
    remove_link /usr/bin/xmlstarlet "${XMLSTARLET_DEST}"
    remove_link /usr/bin/bua "${BUA_CLI_DEST}"

    if [ "${remove_handler}" = "true" ] && [ -f "${CUSTOM_SERVICE_HANDLER}" ]; then
        batocera-services disable custom_service_handler >/dev/null 2>&1
        rm -f "${CUSTOM_SERVICE_HANDLER}"
    fi

    rm -rf "${DEP_DIR:?}" "${ADDONS_DIR:?}/${APPNAME_LC}"
    # The BUA app's settings, history and caches, and the old dialog theme
    rm -f "${ADDONS_DIR}"/bua_* "${ADDONS_DIR}/.dialogrc"
    rmdir "${ADDONS_DIR}" 2>/dev/null

    rm -f "${BATOCERA_ADDONS_PATH}" "${BATOCERA_ADDONS_PATH}.keys"
    rm -f "${BATOCERA_ADDONS_LOGO_DEST}" "${BATOCERA_ADDONS_WHEEL_DEST}"

    rm -f "${DESKTOP_FILE}"
    rm -rf "/userdata/system/configs/${APPNAME_LC}"

    if [ -f "${CUSTOM_STARTUP}" ]; then
        local own
        for own in "${CUSTOM_LINES[@]}"; do
            grep -vxF -- "${own}" "${CUSTOM_STARTUP}" > "${CUSTOM_STARTUP}.tmp"
            cat "${CUSTOM_STARTUP}.tmp" > "${CUSTOM_STARTUP}"
        done
        rm -f "${CUSTOM_STARTUP}.tmp"
    fi

    # The Python hook, written by the installer (python3.12) and by the BUA
    # app (its own Python version); only remove BUA's copy.
    local hook
    for hook in /userdata/system/.local/lib/python3*/site-packages/usercustomize.py; do
        [ -f "${hook}" ] || continue
        if grep -q "configgen.generators" "${hook}" && grep -q "${ADDONS_DIR}" "${hook}"; then
            rm -f "${hook}" "$(dirname "${hook}")"/__pycache__/usercustomize.*.pyc
            rmdir -p "$(dirname "${hook}")/__pycache__" "$(dirname "${hook}")" 2>/dev/null
        fi
    done

    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "BUA has been removed."
}

main "$@"
