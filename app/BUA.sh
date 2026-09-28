#!/usr/bin/env bash

set -u

INSTALL_ROOT="/userdata/system/add-ons/bua"
ARCHIVE_NAME="bua-updater-support-x86_64.tar.gz"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"

BASE_URL="${BUA_RELEASE_BASE_URL:-https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app}"

FRONTEND="${INSTALL_ROOT}/bua_installerx86.py"
LOCAL_HASH_FILE="${INSTALL_ROOT}/.bundle.sha256"

TMP_ROOT="/userdata/system/add-ons/.bua-update.$$"
TMP_ARCHIVE="${TMP_ROOT}/${ARCHIVE_NAME}"
TMP_CHECKSUM="${TMP_ROOT}/${CHECKSUM_NAME}"
TMP_PAYLOAD="${TMP_ROOT}/payload"

cleanup() {
    rm -rf "$TMP_ROOT"
}

trap cleanup EXIT

mkdir -p "$TMP_ROOT" "$TMP_PAYLOAD"

REMOTE_HASH=""

if curl -fL --connect-timeout 10 --max-time 30 \
    "${BASE_URL}/${CHECKSUM_NAME}" \
    -o "$TMP_CHECKSUM" 2>/dev/null; then

    REMOTE_HASH="$(awk 'NR==1 {print $1}' "$TMP_CHECKSUM")"

    case "$REMOTE_HASH" in
        [0-9a-fA-F][0-9a-fA-F]*)
            ;;
        *)
            REMOTE_HASH=""
            ;;
    esac
fi

LOCAL_HASH=""

if [ -f "$LOCAL_HASH_FILE" ]; then
    LOCAL_HASH="$(cat "$LOCAL_HASH_FILE" 2>/dev/null)"
fi

NEED_INSTALL=0

if [ ! -f "$FRONTEND" ]; then
    NEED_INSTALL=1
elif [ -n "$REMOTE_HASH" ] && [ "$REMOTE_HASH" != "$LOCAL_HASH" ]; then
    NEED_INSTALL=1
fi

if [ "$NEED_INSTALL" -eq 1 ]; then
    if [ -z "$REMOTE_HASH" ]; then
        echo "[BUA] Unable to retrieve release checksum."

        if [ ! -f "$FRONTEND" ]; then
            exit 1
        fi
    else
        echo "[BUA] Installing/updating BUA frontend..."

        if ! curl -fL --connect-timeout 10 --max-time 300 \
            "${BASE_URL}/${ARCHIVE_NAME}" \
            -o "$TMP_ARCHIVE"; then

            echo "[BUA] Bundle download failed."

            if [ ! -f "$FRONTEND" ]; then
                exit 1
            fi
        else
            ACTUAL_HASH="$(sha256sum "$TMP_ARCHIVE" | awk '{print $1}')"

            if [ "$ACTUAL_HASH" != "$REMOTE_HASH" ]; then
                echo "[BUA] Bundle checksum verification failed."

                if [ ! -f "$FRONTEND" ]; then
                    exit 1
                fi
            else
                if ! tar -xzf "$TMP_ARCHIVE" -C "$TMP_PAYLOAD"; then
                    echo "[BUA] Bundle extraction failed."

                    if [ ! -f "$FRONTEND" ]; then
                        exit 1
                    fi
                elif [ ! -f "$TMP_PAYLOAD/bua_installerx86.py" ] || \
                     [ ! -d "$TMP_PAYLOAD/updater" ]; then

                    echo "[BUA] Bundle contents are invalid."

                    if [ ! -f "$FRONTEND" ]; then
                        exit 1
                    fi
                else
                    NEW_ROOT="${INSTALL_ROOT}.new"
                    OLD_ROOT="${INSTALL_ROOT}.old"

                    rm -rf "$NEW_ROOT" "$OLD_ROOT"
                    mkdir -p "$NEW_ROOT"

                    cp -a "$TMP_PAYLOAD/." "$NEW_ROOT/"

                    printf '%s\n' "$REMOTE_HASH" \
                        > "$NEW_ROOT/.bundle.sha256"

                    if [ -d "$INSTALL_ROOT" ]; then
                        mv "$INSTALL_ROOT" "$OLD_ROOT"
                    fi

                    if mv "$NEW_ROOT" "$INSTALL_ROOT"; then
                        rm -rf "$OLD_ROOT"
                        echo "[BUA] BUA frontend installed successfully."
                    else
                        echo "[BUA] Installation failed."

                        rm -rf "$NEW_ROOT"

                        if [ -d "$OLD_ROOT" ]; then
                            mv "$OLD_ROOT" "$INSTALL_ROOT"
                        fi

                        if [ ! -f "$FRONTEND" ]; then
                            exit 1
                        fi
                    fi
                fi
            fi
        fi
    fi
fi

if [ ! -f "$FRONTEND" ]; then
    echo "[BUA] Frontend not installed."
    exit 1
fi

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/.Xauthority}"

exec python3 "$FRONTEND"
