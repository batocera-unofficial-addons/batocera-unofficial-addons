#!/bin/bash
# Uninstaller for CasaOS (Docker), installed by casaos.sh.
# Removes the casa container, its image and network, every app installed
# through CasaOS, and the CasaOS data dir. Asks first when CasaOS has apps
# installed; to remove them without asking (in the BUA app: LB+RB on the
# installed apps screen):
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/casaos_uninstall.sh | bash -s -- --ignore-warning

APPNAME="CasaOS"
data_dir="/userdata/system/add-ons/${APPNAME,,}"
CONTAINER="casa"
IMAGE="dockurr/casa"
NETWORK="casa-net"

DOCKER_START="/userdata/system/batocera-containers/batocera-containers"

docker_running() {
    command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

# When Docker is not running, it is started for the uninstall and stopped
# again afterwards.
start_docker() {
    local _
    echo "Docker is not running. Starting it to remove the ${APPNAME} containers..."
    batocera-services start docker >/dev/null 2>&1
    for _ in $(seq 1 60); do
        docker_running && return 0
        sleep 1
    done
    return 1
}

stop_docker() {
    local _
    echo "Stopping Docker again..."
    docker ps -q 2>/dev/null | xargs -r docker stop >/dev/null 2>&1
    pkill -x dockerd
    pkill -f "${DOCKER_START}"
    for _ in $(seq 1 15); do
        pidof dockerd >/dev/null || break
        sleep 1
    done
    pkill -x containerd
}

# Containers CasaOS created for its apps: CasaOS keeps each app's compose
# project under /DATA/AppData/casaos/apps/<app>.
app_containers() {
    local name
    docker ps -a --format '{{.Names}}' | while IFS= read -r name; do
        case "$(docker container inspect -f '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "${name}" 2>/dev/null)" in
            /DATA/AppData/casaos/apps/*) echo "${name}" ;;
        esac
    done
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
    local apps="$1" line list=""
    [ -z "${apps}" ] && return 0

    while IFS= read -r line; do
        list+="  - ${line} ($(docker container inspect -f '{{.Config.Image}}' "${line}" 2>/dev/null))\n"
    done <<< "${apps}"
    echo "WARNING: these apps were installed through ${APPNAME} and will be removed"
    echo "with it, including their containers, images and data:"
    printf '%b\n' "${list}"
    if [ "${ignore_warning}" = "true" ]; then
        echo "Ignoring warnings: removing ${APPNAME} anyway."
        return 0
    fi
    if ask "Uninstall ${APPNAME}" "These apps were installed through ${APPNAME} and will be removed with it, including their containers, images and data:\n\n${list}\nUninstall ${APPNAME}?"; then
        return 0
    fi
    echo "${APPNAME} was not uninstalled."
    return 1
}

# Stops the app, then removes the given containers with their anonymous
# volumes, and the compose networks and images they used where nothing else
# still uses them. Everything is read before anything is stopped.
remove_containers() {
    local targets="$1" name image project info
    info="$(while IFS= read -r name; do
        [ -n "${name}" ] && docker container inspect -f '{{.Image}} {{index .Config.Labels "com.docker.compose.project"}}' "${name}" 2>/dev/null
    done <<< "${targets}")"

    docker stop "${CONTAINER}" >/dev/null 2>&1
    while IFS= read -r name; do
        [ -n "${name}" ] || continue
        docker container inspect "${name}" >/dev/null 2>&1 || continue
        echo "Removing container ${name}..."
        docker rm -f -v "${name}" >/dev/null 2>&1
    done <<< "${targets}"
    while read -r image project; do
        [ -n "${project}" ] || continue
        docker network ls -q --filter "label=com.docker.compose.project=${project}" | xargs -r docker network rm >/dev/null 2>&1
    done <<< "${info}"
    while read -r image _; do
        [ -n "${image}" ] && docker rmi "${image}" >/dev/null 2>&1   # refuses while another container uses it
    done <<< "${info}"
}

main() {
    local started_docker=false apps
    case "${1-}" in
        "") ;;
        --ignore-warning) ignore_warning=true ;;
        *) echo "Usage: casaos_uninstall.sh [--ignore-warning]"; exit 2 ;;
    esac

    # Docker is started, also with --ignore-warning, so the ${APPNAME}
    # containers and images are removed too. If it can't be started, the data
    # dir is still removed.
    if ! docker_running \
        && { command -v docker >/dev/null 2>&1 || [ -e "${DOCKER_START}" ]; }; then
        if start_docker; then
            started_docker=true
        else
            stop_docker >/dev/null
            echo "Docker could not be started, so the ${APPNAME} containers were not removed."
        fi
    fi

    if docker_running; then
        apps="$(app_containers)"
        if ! confirm_removal "${apps}"; then
            [ "${started_docker}" = "true" ] && stop_docker
            exit 1
        fi

        echo "Stopping ${APPNAME}..."
        remove_containers "$(printf '%s\n' "${apps}" "${CONTAINER}")"
        docker network rm "${NETWORK}" >/dev/null 2>&1
        docker rmi "${IMAGE}" >/dev/null 2>&1
        [ "${started_docker}" = "true" ] && stop_docker
    fi

    echo "Removing ${data_dir}..."
    rm -rf "${data_dir:?}"

    echo "${APPNAME} has been removed."
}

main "$@"
