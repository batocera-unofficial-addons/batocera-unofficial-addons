#!/bin/bash
# QEMU Guest Agent uninstaller for Batocera. Stops and removes the qemu_ga
# service, the add-on files and the symlinks BUA made for them in /usr.
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/qga/qga_uninstall.sh | bash

main() {
    echo "========================================="
    echo "Uninstalling: QEMU GA"
    echo "========================================="
    echo ""

    echo "Stopping QEMU Guest Agent..."
    batocera-services stop qemu_ga >/dev/null 2>&1
    batocera-services disable qemu_ga >/dev/null 2>&1
    pkill -x qemu-ga 2>/dev/null   # in case batocera-services didn't

    echo "Removing service: /userdata/system/services/qemu_ga"
    rm -f /userdata/system/services/qemu_ga

    # BUA links the add-on's bin and lib files into /usr; remove only links that point at this add-on
    for link in /usr/bin/qemu-ga /usr/lib/libnuma.so.1 /usr/lib/liburing.so.2; do
        if [ -L "${link}" ] && [[ "$(readlink "${link}")" == /userdata/system/add-ons/qga/* ]]; then
            echo "Removing symlink: ${link}"
            rm -f "${link}"
        fi
    done

    echo "Removing directory: /userdata/system/add-ons/qga"
    rm -rf /userdata/system/add-ons/qga

    echo ""
    echo "========================================="
    echo "Uninstallation complete: QEMU GA"
    echo "========================================="
}

main "$@"
