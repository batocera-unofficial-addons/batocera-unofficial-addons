#!/bin/bash
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
type_text "The installation will start in a few moments. Please wait..."
sleep 2
clear


# Welcome message
echo "Welcome to the automatic installer for the Winconfig by DRL Edition."

# Temporary directory for download
TEMP_DIR="/userdata/tmp/Winconfig"
DRL_FILE="$TEMP_DIR/Winconfig.DRL"
EXTRACT_DIR="$TEMP_DIR/extracted"
DEST_DIR="/"
PORTS_DIR="/userdata/roms/ports"
DEPS_INSTALLER="- Windows Game Fix.sh"

# Create the temporary directories
echo "Creating temporary directories..."
batocera-save-overlay 300
mkdir -p $TEMP_DIR
mkdir -p $EXTRACT_DIR
mkdir -p $PORTS_DIR

# Download the DRL file
echo "Downloading the DRL file..."
curl -L -o $DRL_FILE "https://github.com/DRLEdition19/DRLEdition_Interface/releases/download/files/Winconfig_Files_full_6.0.DRL"

# Check if download was successful
if [ ! -f "$DRL_FILE" ]; then
    echo "Error: Failed to download DRL file"
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

# Find and copy the Winconfig installer
echo "Looking for Winconfig installer..."
FOUND_INSTALLER=$(find "$EXTRACT_DIR" -type f -name "$DEPS_INSTALLER")
if [ ! -z "$FOUND_INSTALLER" ]; then
    echo "Found Winconfig installer. Copying to ports directory..."
    cp -rf "$FOUND_INSTALLER" "$PORTS_DIR/"
    chmod 755 "$PORTS_DIR/$DEPS_INSTALLER"
    echo "Winconfig installer copied successfully to $PORTS_DIR"
else
    echo "Warning: Winconfig installer not found in the extracted files"
fi

# Copy the extracted files to the root directory
echo "Copying files to the system..."
cp -rf $EXTRACT_DIR/* $DEST_DIR

# Create symbolic links
echo "Creating symbolic links..."

# Function to create a symbolic link and remove the target if it already exists
create_symlink() {
    local target="$1"
    local link="$2"

    # Remove existing file or directory
    if [ -e "$link" ] || [ -L "$link" ]; then
        echo "Removing existing link or file: $link"
        rm -rf "$link"
    fi

    # Create the new symbolic link
    ln -s "$target" "$link"
    echo "Created symlink: $link → $target"
}

# create_symlink "/userdata/system/configs/bat-drl/AntiMicroX" "/opt/AntiMicroX"
create_symlink "/userdata/system/configs/bat-drl/AntiMicroX/antimicrox" "/usr/bin/antimicrox"

# Set permissions for specific files
echo "Setting permissions for specific files..."
chmod 777 /userdata/system/configs/bat-drl/AntiMicroX/antimicrox
chmod 777 /userdata/system/configs/bat-drl/AntiMicroX/antimicrox.sh

# Clean up
echo "Cleaning up..."
rm -rf $TEMP_DIR
rm -f "/userdata/system/.local/share/applications/WinConfig.desktop"
rm -f "/userdata/system/.local/share/applications/Remover_WinConfig.desktop"
rm -f "/userdata/system/configs/bat-drl/WindowsGameFix-icon.png"
rm -f "/userdata/system/configs/bat-drl/Remover_WinConfig.png"

# Save changes
echo "Saving changes..."
batocera-save-overlay
echo "Installation completed successfully."

# Gamelist config
# Script para baixar, renomear, configurar permissões e mover um arquivo
# para o diretório do sistema

echo "Iniciando o processo de download e instalação..."

# Download do arquivo
echo "Baixando o arquivo..."
wget -O /tmp/gamelistconfig.sh https://github.com/DRLEdition19/DRLEdition_Interface/raw/refs/heads/main/extra/Winconfig_gamelist_config.sh
echo "Download concluído com sucesso."

# Configura as permissões
echo "Configurando permissões (chmod 777)..."
chmod 777 /tmp/gamelistconfig.sh

# Inicia a ferramenta para configurar o Idioma
xterm -fs 14 -fg white -bg black -fa "Monospace" -en UTF-8 -sb -rightbar -e bash -c "PS1='[\u@\h \$PWD]# ' /bin/bash /tmp/gamelistconfig.sh"

rm -r -f /tmp/gamelistconfig.sh

exit 0
