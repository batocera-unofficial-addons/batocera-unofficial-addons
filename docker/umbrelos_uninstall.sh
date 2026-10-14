#!/bin/bash
# Uninstaller for UmbrelOS (Docker), installed by umbrelos.sh.
# Removes the umbrel container, its image and network, Umbrel's own helper
# containers, every app installed through Umbrel, and the Umbrel data dir.
# Asks first when Umbrel has apps installed; to remove them without asking
# (in the BUA app: LB+RB on the installed apps screen):
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/umbrelos_uninstall.sh | bash -s -- --ignore-warning

APPNAME="Umbrel"
data_dir="/userdata/system/add-ons/${APPNAME,,}"
CONTAINER="umbrel"
IMAGE="dockurr/umbrel"
NETWORK="umbrel_main_network"

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

# Apps installed through Umbrel, by name: each has a dir under
# ${data_dir}/app-data, also when Docker is stopped and Umbrel has removed
# their containers.
installed_apps() {
    local dir name
    for dir in "${data_dir}"/app-data/*/; do
        [ -d "${dir}" ] || continue
        name="$(sed -n 's/^name: *//p' "${dir}umbrel-app.yml" 2>/dev/null | head -n 1 | tr -d "\"'")"
        echo "${name:-$(basename "${dir}")}"
    done
}

# Repositories of the images Umbrel pulled: the ones in its apps' compose
# files, and its own helpers (Tor proxy, LAN ingress), which are set in
# Umbrel's source. Read before ${data_dir} is removed.
umbrel_repos() {
    awk '/^ *image:/ {
            sub(/^ *image: */, "")
            if ($0 == ">-" || $0 == "") { getline; sub(/^ */, "") }
            print
        }' "${data_dir}"/app-data/*/docker-compose.yml 2>/dev/null \
        | sed -E 's/@.*//; s/:[^:/]*$//'
    echo "ghcr.io/getumbrel/tor"
    echo "alpine/socat"
}

# Removes every image from the given repositories, tagged or not. Stopping
# Docker makes Umbrel remove its app containers but not their images, so the
# images can't always be found from the containers.
remove_images() {
    local repos="$1" repo id
    docker images --format '{{.Repository}} {{.ID}}' | while read -r repo id; do
        grep -qxF "${repo}" <<< "${repos}" || continue
        docker rmi "${id}" >/dev/null 2>&1   # refuses while another container uses it
    done
}

# Containers Umbrel created for its apps: each app's compose file is under
# ${data_dir}/app-data/<app>.
app_containers() {
    local name
    docker ps -a --format '{{.Names}}' | while IFS= read -r name; do
        case "$(docker container inspect -f '{{index .Config.Labels "com.docker.compose.project.config_files"}}' "${name}" 2>/dev/null)" in
            *"${data_dir}/app-data/"*) echo "${name}" ;;
        esac
    done
}

# Umbrel's own helper containers (Tor proxy, LAN ingress): compose files from
# /opt/umbreld inside the umbrel container, or com.umbrel.* labels.
helper_containers() {
    local name labels
    docker ps -a --format '{{.Names}}' | while IFS= read -r name; do
        labels="$(docker container inspect -f '{{json .Config.Labels}}' "${name}" 2>/dev/null)"
        case "${labels}" in
            *"${data_dir}/app-data/"*) ;;
            *'"/opt/umbreld/'* | *'"com.umbrel.'*) echo "${name}" ;;
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
        list+="  - ${line}\n"
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
# still uses them. Everything is read before stopping, because stopping
# Umbrel removes its own app containers by itself.
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
    local started_docker=false repos
    case "${1-}" in
        "") ;;
        --ignore-warning) ignore_warning=true ;;
        *) echo "Usage: umbrelos_uninstall.sh [--ignore-warning]"; exit 2 ;;
    esac

    confirm_removal "$(installed_apps)" || exit 1

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
        repos="$(umbrel_repos)"
        echo "Stopping ${APPNAME}..."
        remove_containers "$(printf '%s\n' "$(app_containers)" "$(helper_containers)" "${CONTAINER}")"
        remove_images "${repos}"
        docker network rm "${NETWORK}" >/dev/null 2>&1
        docker rmi "${IMAGE}" >/dev/null 2>&1
        [ "${started_docker}" = "true" ] && stop_docker
    fi

    echo "Removing ${data_dir}..."
    rm -rf "${data_dir:?}"

    echo "${APPNAME} has been removed."
}

main "$@"
