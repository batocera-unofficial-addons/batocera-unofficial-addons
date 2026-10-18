#!/bin/bash
# Uninstaller for Extras (git-developer/batocera-extra), installed by extra.sh.
# Stops and unregisters the batocera-extra services, then removes
# /userdata/extra and the service logs.

EXTRA_DIR="/userdata/extra"
SERVICES_DIR="/userdata/system/services"
LOGS_DIR="/userdata/system/logs"

main() {
    if [ ! -d "${EXTRA_DIR}" ]; then
        echo "Extras is not installed."
        exit 0
    fi

    local service_dir name
    for service_dir in "${EXTRA_DIR}"/*/; do
        service_dir="${service_dir%/}"
        [ -x "${service_dir}/service" ] || continue
        name="$(basename "${service_dir}")"

        echo "Stopping ${name}..."
        batocera-services stop "${name}" >/dev/null 2>&1
        batocera-services disable "${name}" >/dev/null 2>&1
        "${service_dir}/service" stop >/dev/null 2>&1   # in case it wasn't registered

        # Only the service files extra-services register wrote, which exec
        # this service.
        if grep -qsF "${service_dir}/service" "${SERVICES_DIR}/${name}"; then
            rm -f "${SERVICES_DIR}/${name}"
        fi
        rm -f "${LOGS_DIR}/${name}.log"
    done

    echo "Removing ${EXTRA_DIR}..."
    rm -rf "${EXTRA_DIR:?}"

    echo "Extras has been removed."
}

main "$@"
