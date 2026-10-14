#!/bin/bash
# Uninstaller for Docker (batocera-containers + Portainer), installed by docker.sh.
# Removes Docker, Podman, Portainer and all Docker data: every container,
# image and volume. Asks first when other apps run on Docker; to remove it
# without asking, no matter what depends on it (in the BUA app: LB+RB on the
# installed apps screen):
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/docker_uninstall.sh | bash -s -- --ignore-warning

directory="${HOME:-/userdata/system}/batocera-containers"
filename="batocera-containers"
custom_startup="/userdata/system/custom.sh"
restore_script="/userdata/system/batocera-containers/batocera-containers"
SERVICE="/userdata/system/services/docker"

# Paths batocera-containers creates on first run.
CONFIG_DIR="/userdata/system/.config/${filename}"
VAR_LIB="/userdata/system/var/lib"
DATA_ROOT="${VAR_LIB}/containers/docker"
CONTAINERD_ROOT="${VAR_LIB}/containerd"

# Every container in Docker's data dir except Portainer, which docker.sh
# installs itself, as "name (image)". Read from disk so it works whether
# Docker is running or not, and picks up any container, whichever app or
# user created it.
dependents() {
    local config name image
    for config in "${DATA_ROOT}"/containers/*/config.v2.json; do
        [ -f "${config}" ] || continue
        name="$(grep -o '"Name":"/[^"]*"' "${config}" | head -1 | cut -d/ -f2 | tr -d '"')"
        image="$(grep -o '"Image":"[^"]*"' "${config}" | cut -d'"' -f4 | grep -v '^sha256:' | head -1)"
        [ -n "${name}" ] && [ "${name}" != "portainer" ] && echo "${name}${image:+ (${image})}"
    done | sort -u
}

ignore_warning=false   # set to true by --ignore-warning

# Asks a yes/no question in the BUA app, or in the terminal. Returns 0 for
# Yes, 1 for No, a timeout, or no terminal at all. With --ignore-warning,
# every question is answered yes without asking.
ask() {
    local title="$1" text="$2"
    [ "${ignore_warning}" = "true" ] && return 0
    dialog --title "${title}" --clear --timeout 60 --yesno "${text}" 0 0
}

confirm_removal() {
    local apps line list=""
    apps="$(dependents)"
    [ -z "${apps}" ] && return 0

    while IFS= read -r line; do
        list+="  - ${line}\n"
    done <<< "${apps}"
    echo "WARNING: these containers run on Docker. The apps they belong to will"
    echo "stop working, and the containers, their images and volumes will be deleted:"
    printf '%b\n' "${list}"
    if [ "${ignore_warning}" = "true" ]; then
        echo "Ignoring warnings: removing Docker anyway."
        return 0
    fi
    if ask "Uninstall Docker" "These containers run on Docker. The apps they belong to will stop working, and the containers, their images and volumes will be deleted:\n\n${list}\nUninstall Docker?"; then
        return 0
    fi
    echo "Docker was not uninstalled."
    return 1
}

# Removes RAM-side links batocera-containers made into CONFIG_DIR. They go
# away on reboot anyway.
remove_links() {
    local dir link
    for dir in /usr/bin /usr/lib /usr/lib/cni /usr/local/libexec/cni; do
        for link in "${dir}"/*; do
            [ -L "${link}" ] || continue
            case "$(readlink "${link}")" in
                "${CONFIG_DIR}/"*) rm -f "${link}" ;;
            esac
        done
    done
}

main() {
    case "${1-}" in
        "") ;;
        --ignore-warning) ignore_warning=true ;;
        *) echo "Usage: docker_uninstall.sh [--ignore-warning]"; exit 2 ;;
    esac

    confirm_removal || exit 1

    echo "Stopping Docker..."
    batocera-services stop docker >/dev/null 2>&1
    batocera-services disable docker >/dev/null 2>&1
    if command -v docker >/dev/null 2>&1 && pidof dockerd >/dev/null; then
        docker ps -q | xargs -r docker unpause >/dev/null 2>&1
        docker ps -q | xargs -r docker stop >/dev/null 2>&1
    fi
    pkill -x dockerd
    pkill -x containerd
    pkill -f "${restore_script}"
    local _
    for _ in $(seq 1 15); do
        pidof dockerd containerd >/dev/null || break
        sleep 1
    done
    pkill -9 -x dockerd
    pkill -9 -x containerd

    # Anything Docker left mounted under its data dir.
    grep -o " ${VAR_LIB}/[^ ]*" /proc/mounts | sort -r | while read -r mount_point; do
        umount "${mount_point}" 2>/dev/null || umount -l "${mount_point}" 2>/dev/null
    done

    echo "Removing Docker..."
    rm -f "${SERVICE}"
    if [ -f "${custom_startup}" ]; then
        grep -vxF "bash ${restore_script} &" "${custom_startup}" > "${custom_startup}.tmp"
        cat "${custom_startup}.tmp" > "${custom_startup}"
        rm -f "${custom_startup}.tmp"
    fi
    remove_links

    rm -rf --one-file-system "${DATA_ROOT:?}" "${VAR_LIB:?}/containers" "${CONTAINERD_ROOT:?}"
    rmdir "${VAR_LIB}" "${VAR_LIB%/lib}" 2>/dev/null
    rm -rf "${CONFIG_DIR:?}" "${directory:?}"

    echo "Docker has been removed."
}

main "$@"
