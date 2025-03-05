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
type_text "The installation will start in a few moments. Please wait..."
sleep 2
clear


# Welcome message
echo "Welcome to the automatic installer for the J2ME game emulator by DRL Edition."

# Temporary directory for download
TEMP_DIR="/userdata/tmp/freej2me"
DRL_FILE="$TEMP_DIR/freej2me.zip"
DEST_DIR="/"

# Create the temporary directory
echo "Creating temporary directory for download..."
mkdir -p $TEMP_DIR

# Download the drl file
echo "Downloading the freej2me.drl file..."
curl -L -o $DRL_FILE "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/Freej2me/extra/freej2me.zip"

# Extract the drl file with a progress bar and change permissions for each extracted file
echo "Extracting the drl file and setting permissions for each file..."
unzip -o $DRL_FILE -d $TEMP_DIR | while IFS= read -r file; do
    if [ -f "$TEMP_DIR/$file" ]; then
        chmod 777 "$TEMP_DIR/$file"
    fi
done

# Copy the extracted files to the root directory, replacing existing ones
echo "Copying extracted files to the root directory..."
cp -r $TEMP_DIR/* $DEST_DIR

# Create symbolic links
echo "Creating symbolic links..."

# Function to create a symbolic link and replace it if it already exists
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

create_symlink "/userdata/system/configs/bat-drl/AntiMicroX" "/opt/AntiMicroX"
create_symlink "/userdata/system/configs/bat-drl/AntiMicroX/antimicrox" "/usr/bin/antimicrox"
create_symlink "/userdata/system/configs/bat-drl/Freej2me" "/opt/Freej2me"
create_symlink "/userdata/system/configs/bat-drl/python2.7" "/usr/lib/python2.7"

# Set permissions for specific files
echo "Setting permissions for specific files..."
chmod 777 /media/SHARE/system/configs/bat-drl/Freej2me/freej2me.sh
chmod 777 /media/SHARE/system/configs/bat-drl/python2.7/site-packages/configgen/emulatorlauncher.sh
chmod 777 /userdata/system/configs/bat-drl/AntiMicroX/antimicrox
chmod 777 /userdata/system/configs/bat-drl/AntiMicroX/antimicrox.sh

# Delete the freej2me.zip file from the root directory
echo "Deleting the freej2me.zip file from the root directory..."
rm -rf $TEMP_DIR/freej2me.zip
rm -rf /freej2me.zip

# Rename es_system_j2me.cfg to es_systems_j2me.cfg
mv /userdata/system/configs/emulationstation/es_system_j2me.cfg /userdata/system/configs/emulationstation/es_systems_j2me.cfg

# Clean up the temporary directory
echo "Cleaning up temporary directory..."
rm -rf $TEMP_DIR

# Check if the /userdata/system/add-ons/java directory exists
if [ -d "/userdata/system/add-ons/java" ]; then
    echo "The directory /userdata/system/add-ons/java already exists. Exiting script."
    exit 0
fi

# Execute the java.sh script if the /userdata/system/add-ons/java directory does not exist
echo "Executing the java.sh script..."
curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/java/java.sh | bash

echo "Setting permissions for specific files..."
create_symlink "/userdata/system/add-ons/java/java/bin/java" "/usr/bin/java"

# Save changes
echo "Saving changes..."
batocera-save-overlay 300

echo "Installation completed successfully."
killall -9 emulationstation
