#!/bin/bash
# Uninstaller for Gamescope, installed by gamescope.sh.
# Stops and disables gamescope_service, removes its service file, the
# extracted /userdata/system/gamescope folder and the downloaded archive, and
# undoes the links the service made in /usr: links to files Batocera ships
# itself (configgen's emulatorlauncher.py, ES's es_features.cfg) get the
# stock file back, links to files Batocera doesn't ship are deleted.
#
# Asks nothing. --ignore-warning (LB+RB in the BUA app) is accepted, so
# `bua remove --ignore-warning` works the same:
#   curl -L <url> | bash -s -- --ignore-warning

DEST_DIR="/userdata/system"
TAR_PATH="${DEST_DIR}/gamescope.tar.gz"
EXTRACT_DIR="${DEST_DIR}/gamescope"
SERVICE_DST="/userdata/system/services/gamescope_service"

# Batocera's read-only system image, under the RAM overlay that is /.
BASE_DIR="/overlay/base"

main() {
    local arg
    for arg in "$@"; do
        case "${arg}" in
            --ignore-warning) ;;
            *)
                echo "Usage: gamescope_uninstall.sh [--ignore-warning]" >&2
                exit 1
                ;;
        esac
    done

    echo "Removing Gamescope..."

    if command -v batocera-services >/dev/null 2>&1; then
        batocera-services stop gamescope_service >/dev/null 2>&1
        batocera-services disable gamescope_service >/dev/null 2>&1
    fi
    rm -f "${SERVICE_DST}"

    # gamescope_service links files from ${EXTRACT_DIR} over /usr (the
    # gamescope binaries and libraries, a patched configgen and ES
    # features file). Deleting a link that hides a stock file would also
    # hide the stock file (an overlay whiteout) until reboot, so those get
    # a copy of the stock file instead. This comes before removing
    # ${EXTRACT_DIR}, so nothing is left pointing at a missing file.
    local link
    while IFS= read -r -d '' link; do
        if [ -e "${BASE_DIR}${link}" ] || [ -L "${BASE_DIR}${link}" ]; then
            cp -a --remove-destination "${BASE_DIR}${link}" "${link}" \
                && echo "Restored stock ${link}"
        elif [ -d "${BASE_DIR}/usr" ] || [ -d "${link}" ]; then
            rm -f "${link}" && echo "Removed ${link}"
        else
            # Stock image not found: can't tell whether Batocera ships this
            # file, so keep a copy in place until the reboot resets /usr.
            cp -L --remove-destination "${link}" "${link}.gamescope-tmp" 2>/dev/null \
                && mv -f "${link}.gamescope-tmp" "${link}" \
                && echo "Replaced ${link} with a copy until reboot"
        fi
    done < <(find /usr -xdev -type l -lname "${EXTRACT_DIR}/*" -print0 2>/dev/null)

    # The service also links Batocera's NVIDIA allocator in as a GBM
    # backend. Batocera doesn't ship that link, so it goes too.
    local gbm_link="/usr/lib/gbm/nvidia-drm_gbm.so"
    if [ -L "${gbm_link}" ] && [ ! -e "${BASE_DIR}${gbm_link}" ] && [ ! -L "${BASE_DIR}${gbm_link}" ] \
        && [ "$(readlink "${gbm_link}")" = "/usr/lib/libnvidia-allocator.so" ]; then
        rm -f "${gbm_link}" && echo "Removed ${gbm_link}"
    fi

    rm -rf "${EXTRACT_DIR:?}"
    rm -f "${TAR_PATH}"

    echo "Gamescope has been removed."
    # The service also overwrote links other add-ons had made in /usr (for
    # example Sunshine's libwayland-client, the Switch add-on's libsystemd).
    # BUA's symlink service puts its own back within seconds; others only
    # come back when their add-on makes them again at boot.
    echo "Reboot to drop the Gamescope options from EmulationStation's menus"
    echo "and to restore library links other add-ons had in /usr."
}

main "$@"
