#!/bin/bash
# Uninstaller for Quiver Launcher, installed by quiverlauncher.sh.
# Removes the AppImage and its library (settings, app list and the apps it
# installed), the quiver EmulationStation system with its launchers, and the log.

APP_NAME="QuiverLauncher"

ADDONS_DIR="/userdata/system/add-ons"
LOGS_DIR="/userdata/system/logs"
ROMS_DIR="/userdata/roms/quiver"
ES_CONFIG_DIR="/userdata/system/configs/emulationstation"
BATOCERA_CONF="/userdata/system/batocera.conf"

main() {
    echo "Removing ${APP_NAME}..."

    rm -rf "${ADDONS_DIR:?}/${APP_NAME,,}"
    rm -rf "${ROMS_DIR:?}"
    rm -f "${ES_CONFIG_DIR}/es_systems_quiver.cfg" "${ES_CONFIG_DIR}/es_features_quiver.cfg"
    rm -f "${LOGS_DIR}/${APP_NAME,,}.log"
    # System settings (quiver.x) and per-game ones Batocera adds (quiver["Game.sh"].x)
    sed -i '/^quiver\./d; /^quiver\[/d' "${BATOCERA_CONF}" 2>/dev/null || true

    echo "${APP_NAME} has been removed."

    # The quiver system is gone; EmulationStation must restart to drop it
    killall -9 emulationstation
}

main "$@"
