#!/bin/bash
# Uninstaller for Freej2me (DRL Edition), installed by Install_j2me.sh.
# AntiMicroX and the private Java copy in bat-drl are removed too. When
# another installed add-on still uses one, it first asks whether to uninstall
# Freej2me at all, then whether to remove each shared part. To answer yes to
# everything without asking (in the BUA app: LB+RB on the installed apps
# screen):
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/Freej2me/Install_j2me_uninstall.sh | bash -s -- --ignore-warning

ADDON_NAME="freej2me"
ADDON_DIR="/userdata/system/add-ons/${ADDON_NAME}"
SERVICE="/userdata/system/services/${ADDON_NAME}"
LOG="/userdata/system/logs/${ADDON_NAME}.log"
CONFIGGEN="/usr/share/batocera/configgen/configgen-defaults.yml"
FILE2="/userdata/system/batocera.conf"
CUSTOM_SH="/userdata/system/custom.sh"

BAT_DRL="/userdata/system/configs/bat-drl"
FREEJ2ME_DIR="${BAT_DRL}/Freej2me"
JAVA_DIR="${BAT_DRL}/java"
ANTIMICROX_DIR="${BAT_DRL}/AntiMicroX"
BIOS_DIR="/userdata/bios"
ROMS_DIR="/userdata/roms/j2me"
PORTS_DIR="/userdata/roms/ports"
ES_DIR="/userdata/system/configs/emulationstation"
EVMAPY_DIR="/userdata/system/configs/evmapy"

# Games bundled in Freej2me.DRL. Only these are removed from roms/j2me, so
# games the user added stay.
bundled_games() {
    cat <<'GAMES'
Adventure Time_ Heroes of Hoo 240x320 [BR].jar
Age of Empires 3 240x320 [BR].jar
Angry Birds 240x320 [BR].jar
Angry Birds_ Star Wars 240x320 [BR].jar
As Aventuras de Tintim 240x320 [BR].jar
Asphalt 3_ Street Rules 3D 240x320 [BR].jar
Asphalt 4_ Elite Racing 240x320 [BR].jar
Asphalt 6_ Adrenaline 240x320 [BR].jar
Assassin's Creed 240x320 [BR].jar
Asterix & Obelix Visitam Cleopatra 240x320 [BR].jar
Batman_ Guardiao de Gothan 240x320 [BR].jar
Batman_ O Cavaleiro das Trevas 240x320 [BR].jar
Ben 10 and Bonus Game 240x320 [BR].jar
Ben 10_ A Vinganca de Vilgax 240x320 [BR].jar
Ben 10_ O Poder do Omnitrix 240x320 [BR].jar
Ben 10_ Omniverse 240x320 [BR].jar
Ben 10_ Ultimate Alien 240x320 [BR].jar
Ben10 Alien Force - Break In and Bust Out_BRP.jar
Beyblade G Revolution 240x320 [BR].jar
Bird Hunter Pro 240x320 [BR].jar
Block Breaker 3_ Unlimited 240x320 [BR].jar
Block'd 240x320 [BR].jar
Block3D 2 240x320 [BR].jar
Bob Esponja Multiresolucao [BR].jar
Bolt_ The Movie Game 240x320 [BR].jar
Bomberman_ Atomic 3D 240x320 [BR].jar
Bomberman_ Deluxe Multiresolucao [BR].jar
Brothers in Arms_ Art of War 240x320 [BR].jar
Bubble Bash 2 240x320 [BR].jar
Bubble Bash 240x320 [BR].jar
Bubble Bash Mania 240x320 [BR].jar
Call of Duty_ Modern Warfare_ Force Recon 240x320 [BR].jar
Diamond Islands Multiresolucao [BR].jar
Diamond Rush 240x320 [BR].jar
Ferrari GT_ Evolution 240x320 [BR].jar
Fifa 2010 240x320 [BR].jar
Fifa Manager 2012 240x320 [BR].jar
Fifa World Cup Brasil 2014 240x320 [BR].jar
Furia De Titans 240x320 [BR].jar
GT Racing 2 240x320 [BR].jar
Gangstar 1 Crime City 240x320 [BR].jar
Gangstar City 240x320 [BR].jar
Generator Rex Multiresolucao [BR].jar
God of War Betrayal 240x320 [BR].jar
Guitar Hero 3 240x320 [BR].jar
Harry Potter e as Reliquias da Morte_ Parte 1 240x320 [BR].jar
Hero of Sparta 240x320 [BR].jar
Jurassic Park 240x320 [BR].jar
KO Fighters 240x320 [BR].jar
Kart Mania 3D 240x320 [BR].jar
King Kong 240x320 [BR].jar
Little Big City 240x320 [BR].jar
Medal of Honor 240x320 [BR].jar
Miami Nights 240x320 [BR].jar
Midnight Bowling 3 240x320 [BR].jar
Midnight Pool 3 240x320 [BR].jar
Moto GP 2012 Multiresolucao [BR].jar
N.O.V.A. 3 240x320 [BR].jar
Need For Speed_ Pro Street 240x320 [BR].jar
Need For Speed_ Undercover Multiresolucao [BR].jar
Nitro Street Racing 2 240x320 Touch [BR].jar
Nitro Street Racing 240X320 [BR].jar
Pes 2010 240x320 [BR].jar
Prince of Persia Zero 240x320 [BR].jar
Prince of Persia_ Os Dois Tronos 240x320 [BR].jar
Rayman Kart 240x320 [BR].jar
Resident Evil_ The Missions 240x320 [BR].jar
Shrek_ Party 240x320 [BR].jar
Sim City_ Deluxe 240x320 [BR].jar
Sim City_ Metropolis 240x320 [BR].jar
Snake 3 240x320 [BR].jar
Snake_ Revolution Multiresolucao [BR].jar
Sonic The Hedgehog_ Part One 240x320 [BR].jar
Sonic_ Sega All Stars Racing 240x320 [BR].jar
Sonic_ Unleashed 240x320 [BR].jar
Spider Man 3 240x320 [BR].jar
Star Wars_ Imperial Ace 3D 240x320 [BR].jar
Street Fighter Alpha_ Warriors Dreams 240x320 [BR].jar
Super Mario Bros 240x320 [BR].jar
Superman e Batman_ Heroes United 240x320 [BR].jar
The Simpsons 2_ Itchy & Scratchy Land 240x320 [BR].jar
The Sims 2_ Castaway 240x320 [BR].jar
The Sims 3 240x320 [BR].jar
Thor_ O Mundo Sombrio 240x320 [BR].jar
Tony Hawk Vert 240x320 [BR].jar
Transformers 2 Multiresolucao [BR].jar
Transformers 3_ O Lado Oculto Da Lua 240x320 [BR].jar
UNO 240x320 [BR].jar
X Men Origins Wolverine 240x320 [BR].jar
GAMES
}

# Prints what, other than the given dir and Freej2me itself, still refers to
# the pattern: launchers, services, other bat-drl packages, ES systems,
# custom.sh, and symlinks in other add-ons (e.g. f1/bin/antimicrox). One name
# per line, nothing when unused.
users_of() {
    local pattern="$1" dep_dir="$2" path link
    for path in "${BAT_DRL}"/* "${PORTS_DIR}"/*.sh /userdata/system/services/* \
                "${ES_DIR}"/es_systems_*.cfg "${CUSTOM_SH}"; do
        [ -e "${path}" ] || continue
        case "${path}" in
            "${dep_dir}" | "${FREEJ2ME_DIR}" | "${SERVICE}" | "${PORTS_DIR}/-Update_j2me.sh" | \
                "${ES_DIR}/es_systems_j2me.cfg") continue ;;
        esac
        grep -rqsiI -e "${pattern}" "${path}" && basename "${path}"
    done
    find /userdata/system/add-ons -mindepth 2 -maxdepth 3 -ilname "*${pattern}*" 2>/dev/null |
        while IFS= read -r link; do
            link="${link#/userdata/system/add-ons/}"
            [ "${link%%/*}" = "${ADDON_NAME}" ] && continue
            echo "${link%%/*} add-on"
        done | sort -u
}

# "  - <dir>, used by: <app>, <app>" for a shared part other apps use.
shared_line() {
    local dep_dir="$1" users="$2"
    [ -n "${users}" ] || return 0
    echo "  - ${dep_dir}, used by: $(paste -sd ',' <<< "${users}" | sed 's/,/, /g')"
}

ignore_warning=false   # set to true by --ignore-warning in main

# Asks a yes/no question in the BUA app, or in the terminal. Returns 0 for
# Yes, 1 for No, a timeout, or no terminal at all. With --ignore-warning,
# every question is answered yes without asking.
ask() {
    local title="$1" text="$2"
    [ "${ignore_warning}" = "true" ] && return 0
    dialog --title "${title}" --clear --timeout 60 --yesno "${text}" 0 0
}

# Removes a shared dir. When another installed app still uses it (the given
# users), asks first: Yes removes it, No keeps it.
remove_shared() {
    local dep_dir="$1" users="$2" line list=""
    [ -d "${dep_dir}" ] || return 0
    if [ -n "${users}" ]; then
        while IFS= read -r line; do
            list+="  - ${line}\n"
        done <<< "${users}"
        echo "WARNING: ${dep_dir} is still used by:"
        printf '%b\n' "${list}"
        if ! ask "Uninstall Freej2me" "${dep_dir} came with Freej2me, and these apps still use it:\n\n${list}\nRemove it anyway? They may stop working."; then
            echo "Keeping ${dep_dir}."
            return 0
        fi
        [ "${ignore_warning}" = "true" ] && echo "Ignoring warnings: removing ${dep_dir} anyway."
    fi
    echo "Removing ${dep_dir}..."
    rm -rf "${dep_dir:?}"
}

main() {
    case "${1-}" in
        "") ;;
        --ignore-warning) ignore_warning=true ;;
        *) echo "Usage: Install_j2me_uninstall.sh [--ignore-warning]"; exit 2 ;;
    esac

    # Read before anything is removed, so No leaves Freej2me as it was.
    local java_users antimicrox_users shared
    [ -d "${JAVA_DIR}" ] && java_users="$(users_of "bat-drl/java" "${JAVA_DIR}" | sort -u)"
    [ -d "${ANTIMICROX_DIR}" ] && antimicrox_users="$(users_of "antimicrox" "${ANTIMICROX_DIR}" | sort -u)"
    shared="$(shared_line "${JAVA_DIR}" "${java_users}"; shared_line "${ANTIMICROX_DIR}" "${antimicrox_users}")"
    if [ -n "${shared}" ]; then
        echo "WARNING: Freej2me shares these parts with other apps:"
        echo "${shared}"
        if ! ask "Uninstall Freej2me" "Freej2me shares these parts with other apps:\n\n${shared}\n\nUninstall Freej2me? You will be asked next whether to remove each shared part."; then
            echo "Freej2me was not uninstalled."
            exit 1
        fi
    fi

    echo "Stopping Freej2me service..."
    # Stopping removes the links into /usr and restores any .bak originals.
    batocera-services stop "${ADDON_NAME}" >/dev/null 2>&1
    batocera-services disable "${ADDON_NAME}" >/dev/null 2>&1
    [ -x "${SERVICE}" ] && "${SERVICE}" stop >/dev/null 2>&1   # in case batocera-services didn't
    rm -f "${SERVICE}"

    echo "Removing Freej2me..."
    rm -rf "${ADDON_DIR:?}"
    rm -rf "${FREEJ2ME_DIR:?}"
    rm -f "${PORTS_DIR}/-Update_j2me.sh"
    rm -f "${ES_DIR}/es_systems_j2me.cfg" "${ES_DIR}/es_features_j2me.cfg" "${ES_DIR}/BKP-es_systems.cfgr"
    rm -f "${EVMAPY_DIR}/j2me.keys"
    rm -f "${LOG}"

    local jar
    for jar in freej2me.jar freej2me-fx.jar freej2me-lr.jar freej2me-sdl.jar; do
        case "$(readlink "${BIOS_DIR}/${jar}" 2>/dev/null)" in
            "${FREEJ2ME_DIR}/"*) rm -f "${BIOS_DIR}/${jar}" ;;
        esac
    done

    echo "Removing bundled games..."
    local game
    while IFS= read -r game; do
        rm -f "${ROMS_DIR}/${game}"
    done < <(bundled_games)
    rmdir "${ROMS_DIR}" 2>/dev/null

    # Settings added by the installer, with the blank line before them.
    if [ -f "${FILE2}" ]; then
        awk '
            /^$/ { blank++; next }
            $0 == "j2me.core=freej2me" || $0 == "j2me.emulator=libretro" { blank = 0; next }
            { while (blank > 0) { print ""; blank-- } print }
            END { while (blank > 0) { print ""; blank-- } }
        ' "${FILE2}" > "${FILE2}.tmp" && mv "${FILE2}.tmp" "${FILE2}"
    fi

    # The service's j2me block in configgen-defaults.yml (RAM overlay, gone on
    # reboot anyway).
    if [ -f "${CONFIGGEN}" ] && grep -qx "  core:     freej2me" "${CONFIGGEN}"; then
        awk '
            { line[NR] = $0 }
            END {
                for (i = 1; i <= NR; i++) {
                    b = (line[i] == "") ? 1 : 0
                    if (line[i+b] == "j2me:" && line[i+b+1] == "  emulator: libretro" && line[i+b+2] == "  core:     freej2me") {
                        i += b + 2; continue
                    }
                    print line[i]
                }
            }
        ' "${CONFIGGEN}" > "${CONFIGGEN}.tmp" && cat "${CONFIGGEN}.tmp" > "${CONFIGGEN}"
        rm -f "${CONFIGGEN}.tmp"
    fi

    remove_shared "${JAVA_DIR}" "${java_users}"
    remove_shared "${ANTIMICROX_DIR}" "${antimicrox_users}"

    rmdir "${BAT_DRL}" 2>/dev/null

    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "Freej2me has been removed."
}

main "$@"
