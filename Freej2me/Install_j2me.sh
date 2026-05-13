#!/bin/bash
clear

# Exibe mensagem inicial 
echo "Presenting..."
sleep 2

# Limpa o terminal
#clear

# Função para exibir data e hora atual
show_current_time() {
    echo -e "Current Date and Time (UTC): $(date '+%Y-%m-%d %H:%M:%S')"
    echo
}

# Função para animação de digitação
type_text() {
    text="$1"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep 0.05
    done
    echo
}

# Códigos de cores ANSI
blue="\e[34m"   # cor final: azul
reset="\e[0m"

# Vetor expandido com 15 cores em degradê
colors=(
    "\e[38;5;196m"  # Vermelho vivo
    "\e[38;5;202m"  # Laranja escuro
    "\e[38;5;208m"  # Laranja
    "\e[38;5;214m"  # Laranja claro
    "\e[38;5;220m"  # Amarelo
    "\e[38;5;226m"  # Amarelo brilhante
    "\e[38;5;190m"  # Verde-amarelado
    "\e[38;5;118m"  # Verde claro
    "\e[38;5;46m"   # Verde
    "\e[38;5;48m"   # Verde água
    "\e[38;5;51m"   # Ciano
    "\e[38;5;45m"   # Azul claro
    "\e[38;5;39m"   # Azul
    "\e[38;5;63m"   # Azul-violeta
    "\e[38;5;129m"  # Violeta
)

# Arte ASCII do DRL Edition
ascii_art=(
"██████╗ ██████╗  ██╗         ███████╗██████╗ ██╗████████╗██╗ ██████╗ ███╗   ██╗"
"██╔══██╗██╔══██╗ ██║         ██╔════╝██╔══██╗██║╚══██╔══╝██║██╔═══██╗████╗  ██║"
"██║  ██║██████╔╝ ██║         █████╗  ██║  ██║██║   ██║   ██║██║   ██║██╔██╗ ██║"
"██║  ██║██╔══██╗ ██║         ██╔══╝  ██║  ██║██║   ██║   ██║██║   ██║██║╚██╗██║"
"██████╔╝██║  ██║ ███████╗    ███████╗██████╔╝██║   ██║   ██║╚██████╔╝██║ ╚████║"
"╚═════╝ ╚═╝  ╚═╝ ╚══════╝    ╚══════╝╚═════╝ ╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
)

# Animação da arte ASCII com efeito degradê
for ((k=0; k<3; k++)); do  # 3 ciclos completos
    for ((i=0; i<${#colors[@]}; i++)); do
        clear
        # Mostra data e hora 
        show_current_time
        
        # Mostra a arte ASCII na cor atual do degradê
        for line in "${ascii_art[@]}"; do
            echo -e "${colors[$i]}${line}${reset}"
        done
        sleep 0.1
    done
done

# Mostra a versão final em azul
clear
show_current_time
for line in "${ascii_art[@]}"; do
    echo -e "${blue}${line}${reset}"
done

# Pula uma linha
echo ""

# Mensagem final com animação de digitação
echo -ne "${PURPLE}"  # Cor roxa para a mensagem final
type_text "Thank you for running this script!"  
type_text "Developed by DRLEdition19"  
type_text "Please wait, the process is in progress..."
sleep 2
clear


# Welcome message
echo "Welcome to the automatic installer for the Freej2me by DRL Edition."
type_text "Java j2me game emulator tested and working on Batocera v.42"

# Temporary directory for download
TEMP_DIR="/userdata/tmp/Freej2me"
DRL_FILE="$TEMP_DIR/Freej2me.DRL"
EXTRACT_DIR="$TEMP_DIR/extracted"
DEST_DIR="/userdata/system/add-ons/freej2me/rootfs"

# Create the temporary directories
echo "Creating temporary directories..."
mkdir -p $TEMP_DIR
mkdir -p $EXTRACT_DIR
mkdir -p $DEST_DIR

# Download the DRL file
echo "Downloading the Freej2me.DRL file..."
curl -L -o $DRL_FILE "https://github.com/DRLEdition19/batocera-unofficial-addons.add/releases/download/files/Freej2me.DRL"

# Check if download was successful
if [ ! -f "$DRL_FILE" ]; then
    echo "Error: Failed to download Freej2me.DRL"
    exit 1
fi

# Extract the squashfs file
echo "Extracting the DRL file..."
unsquashfs -f -d "$EXTRACT_DIR" "$DRL_FILE"

# Check if extraction was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to extract the DRL file"
    rm -rf $TEMP_DIR
    exit 1
fi

# Copy the extracted files to the addon rootfs directory
echo "Copying files to the system..."
cp -r $EXTRACT_DIR/userdata/. /userdata/ 2>/dev/null || true
cp -r $EXTRACT_DIR/usr $DEST_DIR/ 2>/dev/null || true
cp -r $EXTRACT_DIR/etc $DEST_DIR/ 2>/dev/null || true

FILE2="/userdata/system/batocera.conf"

# Check if the information is already in the file batocera.conf
if ! grep -q "j2me" "$FILE2"; then
    # Add the desired content to the file
    echo -e "\nj2me.core=freej2me\nj2me.emulator=libretro" >> "$FILE2"
    echo "Information added to batocera.conf."
else
    echo "batocera.conf entry already exists. No changes made."
fi

# Clean up
echo "Cleaning up..."
rm -rf $TEMP_DIR

# Write the freej2me service script
echo "Installing freej2me service..."
mkdir -p /userdata/system/services
cat << 'SERVICEEOF' > /userdata/system/services/freej2me
#!/bin/bash

ADDON_NAME="freej2me"
ADDON_DIR="/userdata/system/add-ons/${ADDON_NAME}"
ROOTFS="${ADDON_DIR}/rootfs"
LOG="/userdata/system/logs/${ADDON_NAME}.log"
CONFIGGEN="/usr/share/batocera/configgen/configgen-defaults.yml"

log() { echo "$(date): $*" | tee -a "$LOG"; }

link_file() {
    local src="$1"
    local target="${src#${ROOTFS}}"
    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ]; then
        local cur; cur="$(readlink "$target")"
        if [ "$cur" = "$src" ]; then
            return
        else
            log "Conflict: $target -> $cur (expected $src). Skipping."
            return
        fi
    elif [ -e "$target" ]; then
        log "Backing up: $target -> ${target}.bak"
        mv "$target" "${target}.bak"
    fi

    log "Linking: $target -> $src"
    ln -s "$src" "$target"
}

unlink_file() {
    local src="$1"
    local target="${src#${ROOTFS}}"

    if [ -L "$target" ]; then
        local cur; cur="$(readlink "$target")"
        if [ "$cur" = "$src" ]; then
            log "Removing symlink: $target"
            rm "$target"
            [ -e "${target}.bak" ] && { log "Restoring: ${target}.bak"; mv "${target}.bak" "$target"; }
        else
            log "Symlink $target -> $cur, not our file. Skipping."
        fi
    elif [ -e "${target}.bak" ]; then
        log "Orphan backup found — restoring: ${target}.bak"
        mv "${target}.bak" "$target"
    fi
}

apply_symlinks() {
    [ -d "$ROOTFS" ] || { log "ERROR: rootfs missing at $ROOTFS"; exit 1; }
    find "$ROOTFS" -type f | while read -r src; do link_file "$src"; done
    log "Symlink pass complete."
}

remove_symlinks() {
    [ -d "$ROOTFS" ] || { log "rootfs missing, nothing to remove."; return; }
    find "$ROOTFS" -type f | while read -r src; do unlink_file "$src"; done
    log "Symlink removal complete."
}

patch_configgen() {
    if [ -f "$CONFIGGEN" ] && ! grep -q "j2me:" "$CONFIGGEN"; then
        echo -e "\nj2me:\n  emulator: libretro\n  core:     freej2me" >> "$CONFIGGEN"
        log "Patched configgen-defaults.yml"
    fi
}

case "$1" in
    start)
        mkdir -p /userdata/system/logs
        log "Starting freej2me overlay..."
        apply_symlinks
        patch_configgen
        ;;
    stop)
        mkdir -p /userdata/system/logs
        log "Stopping freej2me overlay..."
        remove_symlinks
        ;;
    status)
        if [ ! -d "$ROOTFS" ]; then
            echo "freej2me: not installed (rootfs missing)."
            exit 1
        fi
        missing=0
        while IFS= read -r src; do
            target="${src#${ROOTFS}}"
            [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ] || missing=$((missing+1))
        done < <(find "$ROOTFS" -type f)
        [ "$missing" -eq 0 ] && echo "freej2me: all symlinks active." \
                              || echo "freej2me: ${missing} symlink(s) missing or broken."
        grep -q "j2me:" "$CONFIGGEN" 2>/dev/null \
            && echo "freej2me: configgen entry present." \
            || echo "freej2me: configgen entry missing."
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
SERVICEEOF

chmod +x /userdata/system/services/freej2me

# Enable and start the service
batocera-services enable freej2me
batocera-services start freej2me
clear

type_text "Installation completed successfully."
type_text "Developed by DRLEdition19"
desktop
killall -9 pcmanfm
killall -9 emulationstation
exit 0
