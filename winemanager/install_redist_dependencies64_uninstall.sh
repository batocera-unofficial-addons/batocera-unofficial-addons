#!/bin/bash
# Uninstaller for Wine Dependencies x64, installed by
# install_redist_dependencies64.sh.
#
# The installer puts the x64 Visual C++ redistributables and the DirectX
# redistributable (directx.7z, extracted) in /userdata/system/wine/exe.
# On the next Windows game launch, Batocera's wine runner installs every .exe
# found there into that game's bottle and moves the .exe to
# /userdata/system/wine/installed.exe. Wine Manager's "disable redist
# install" Ports entry renames the folder to exe.bak. This script removes
# the add-on's files from all three folders, and the folders themselves when
# nothing else is left in them.
#
# What was already installed into a game's Wine bottle stays there: it can
# only be removed by deleting that bottle.
#
# The DirectX files are the same ones Wine Dependencies x86
# (install_redist_dependencies32.sh) extracts. If its files are found, the
# script asks before removing the DirectX files.
#
# Usage:
#   curl -L <url> | bash
#   curl -L <url> | bash -s -- --ignore-warning   (remove without asking)
# In the BUA app, --ignore-warning is LB+RB on the Updater screen.

APP_NAME="Wine Dependencies x64"

# Same folder as the installer
WINE_EXE_DIR="/userdata/system/wine/exe"
# Folders Batocera's wine runner and Wine Manager move these files to
WINE_EXE_BAK_DIR="${WINE_EXE_DIR}.bak"
WINE_INSTALLED_DIR="${WINE_EXE_DIR%/*}/installed.exe"

# The x64 installers the installer downloads with wget
VCREDIST_FILES=(
    vcredist_x64_2015_2019.exe
    vcredist_x64_2019.exe
    vcredist_x64_2017.exe
    vcredist_x64_2015.exe
    vcredist_x64_2013.exe
    vcredist_x64_2012.exe
    vcredist_x64_2010.exe
    vcredist_x64_2008.exe
    vcredist_x64_2005.exe
)

# What directx.7z extracts (the DirectX June 2010 redistributable):
# DXSETUP.exe, its DLLs and installscript.vdf, plus one .cab per component
# and release, named like Jun2010_d3dx11_43_x64.cab.
DIRECTX_FILES=(
    DXSETUP.exe
    DSETUP.dll
    dsetup32.dll
    installscript.vdf
    dxdllreg_x86.cab
    dxupdate.cab
    "[A-Za-z][A-Za-z][A-Za-z]20[01][0-9]_*.cab"
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

# Removes the files matching the given names from every folder. A trailing *
# also catches the copies wget makes when the installer runs again
# (name.exe.1) and the backups Batocera makes when it moves a file that is
# already in installed.exe (name.exe.~1~).
remove_files() {
    local dir name
    for dir in "${WINE_EXE_DIR}" "${WINE_EXE_BAK_DIR}" "${WINE_INSTALLED_DIR}"; do
        [ -d "${dir}" ] || continue
        for name in "$@"; do
            # shellcheck disable=SC2086  # name may be a glob pattern
            rm -f "${dir:?}"/${name} "${dir:?}"/${name}.[0-9]* "${dir:?}"/${name}.~[0-9]*~
        done
    done
}

main() {
    local arg
    for arg in "$@"; do
        case "${arg}" in
            --ignore-warning) ignore_warning=true ;;
            *)
                echo "Usage: install_redist_dependencies64_uninstall.sh [--ignore-warning]"
                exit 1
                ;;
        esac
    done

    echo "Removing ${APP_NAME}..."

    remove_files "${VCREDIST_FILES[@]}"
    echo "Removed the x64 Visual C++ redistributables."

    # The DirectX files are shared with Wine Dependencies x86.
    local dir x86_dirs=""
    for dir in "${WINE_EXE_DIR}" "${WINE_EXE_BAK_DIR}" "${WINE_INSTALLED_DIR}"; do
        if compgen -G "${dir}/vcredist_x86_*" >/dev/null; then
            x86_dirs="${x86_dirs}\n  ${dir}"
        fi
    done

    if [ -z "${x86_dirs}" ]; then
        remove_files "${DIRECTX_FILES[@]}"
        echo "Removed the DirectX redistributable."
    else
        local text="The DirectX files in ${WINE_EXE_DIR} are also used by Wine Dependencies x86, which is still installed (its files are in:${x86_dirs}).\n\nRemove the DirectX files anyway?"
        echo -e "${text}"
        if ask "Remove DirectX files?" "${text}"; then
            [ "${ignore_warning}" = "true" ] && echo "--ignore-warning given: removing them anyway."
            remove_files "${DIRECTX_FILES[@]}"
            echo "Removed the DirectX redistributable."
        else
            echo "Kept the DirectX files for Wine Dependencies x86."
        fi
    fi

    # Remove the folders only when nothing else is left in them (other
    # add-ons, such as Steamy-AIO, and the user put files there too).
    for dir in "${WINE_EXE_DIR}" "${WINE_EXE_BAK_DIR}" "${WINE_INSTALLED_DIR}"; do
        [ -d "${dir}" ] && rmdir "${dir}" 2>/dev/null
    done

    echo "Anything already installed into a game's Wine bottle stays there."
    echo "${APP_NAME} has been removed."
    exit 0
}

main "$@"
