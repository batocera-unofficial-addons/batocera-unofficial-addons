#!/bin/bash

# --- Diretórios e Configurações Globais ---
readonly ATALHO="/userdata/system/.local/share/applications/WinConfig.desktop"
readonly TARGET_DIR="/userdata/roms/ports"
readonly TARGET_FILE="gamelist.xml"
readonly GAMELIST_FILE_PATH="${TARGET_DIR}/${TARGET_FILE}"
readonly WGM_FILE="/userdata/roms/ports/- Windows Game Fix.sh"
readonly TEMP_FILE=$(mktemp) || { echo "Erro ao criar arquivo temporário."; }

# Cria diretórios essenciais se não existirem
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_BASE_DIR"

####################################################################################################
# Função para alterar idioma - Início
####################################################################################################
####################################################################################################

# comando para remover inforações antigas do "gamelist.xml"
limpargamelist() {
FULL_PATH="${GAMELIST_FILE_PATH}"
# Verifica se o arquivo existe
if [ ! -f "$FULL_PATH" ]; then
    echo "Erro: O arquivo '$TARGET_FILE' não foi encontrado."
    # exit 1
fi

# Verifica se as linhas específicas existem
if grep -q "<game>" "$FULL_PATH" && grep -q "       <path>./- Windows Game Fix.sh</path>" "$FULL_PATH"; then
    echo "As linhas de verificação foram encontradas. Iniciando a remoção de 52 linhas..."

    # Encontra o número da linha onde começa a primeira ocorrência de "<game>"
    # que é seguida por "<path>./- Windows Game Fix.sh</path>"
    START_LINE=$(grep -n -A 1 "<game>" "$FULL_PATH" | grep -B 1 "       <path>./- Windows Game Fix.sh</path>" | head -n 1 | cut -d: -f 1)

    if [ -z "$START_LINE" ]; then
        echo "Não foi possível determinar a linha inicial para a remoção."
        # exit 1
    fi

    END_LINE=$((START_LINE + 51)) # 50 linhas abaixo da primeira, totalizando 52

    echo "Removendo linhas de $START_LINE a $END_LINE..."

    # Usa sed para excluir as linhas
    sed -i "${START_LINE},${END_LINE}d" "$FULL_PATH"
    echo "As linhas foram removidas com sucesso de '$TARGET_FILE'."
else
    echo "As linhas de verificação não foram encontradas. Nenhuma ação será tomada."
fi
}

# Comando para instalar o idioma em Portugês Brasil
ptbr() {
    # Caminho do arquivo de idioma
    local drl_file="/userdata/roms/ports/- Windows Game Fix.sh"

    # Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$drl_file" << EOF
#!/bin/bash
winconfig-redist-pt
EOF

    # Ajusta as permissões
    chmod 777 "$drl_file"

# Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$ATALHO" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WinConfig - Windows Game Fix
Exec=winconfig-redist-pt
Terminal=false
Categories=Utility;Application;batocera.linux;
Icon=/userdata/system/configs/bat-drl/WindowsGameFix-icon.png
EOF

    # Ajusta as permissões
    chmod 777 "$ATALHO"
    
    # Executa o comando winconfig-redist-lang, se existir
    if command -v winconfig-redist-lang >/dev/null 2>&1; then
        winconfig-redist-lang
    else
        warning "Comando 'winconfig-redist-lang' não encontrado!"
    fi
}

# Comando para instalar o idioma em Inglês
ingles() {
# --- Início da Lógica ---
aplicargamelist

    # Caminho do arquivo de idioma
    local drl_file="/userdata/roms/ports/- Windows Game Fix.sh"

    # Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$drl_file" << EOF
#!/bin/bash
winconfig-redist-en
EOF

    # Ajusta as permissões
    chmod 777 "$drl_file"

# Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$ATALHO" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WinConfig - Windows Game Fix
Exec=winconfig-redist-en
Terminal=false
Categories=Utility;Application;batocera.linux;
Icon=/userdata/system/configs/bat-drl/WindowsGameFix-icon.png
EOF

    # Ajusta as permissões
    chmod 777 "$ATALHO"
    
    # Executa o comando winconfig-redist-lang, se existir
    if command -v winconfig-redist-lang >/dev/null 2>&1; then
        winconfig-redist-lang
    else
        warning "Comando 'winconfig-redist-lang' não encontrado!"
    fi
}

# Comando para instalar o idioma em Espanhol
espanhol() {
    # Caminho do arquivo de idioma
    local drl_file="/userdata/roms/ports/- Windows Game Fix.sh"

    # Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$drl_file" << EOF
#!/bin/bash
winconfig-redist-es
EOF

    # Ajusta as permissões
    chmod 777 "$drl_file"

# Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$ATALHO" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WinConfig - Windows Game Fix
Exec=winconfig-redist-es
Terminal=false
Categories=Utility;Application;batocera.linux;
Icon=/userdata/system/configs/bat-drl/WindowsGameFix-icon.png
EOF

    # Ajusta as permissões
    chmod 777 "$ATALHO"
    
    # Executa o comando winconfig-redist-lang, se existir
    if command -v winconfig-redist-lang >/dev/null 2>&1; then
        winconfig-redist-lang
    else
        warning "Comando 'winconfig-redist-lang' não encontrado!"
    fi
}

# Comando para instalar o idioma em Italiano
italiano() {
    # Caminho do arquivo de idioma
    local drl_file="/userdata/roms/ports/- Windows Game Fix.sh"

    # Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$drl_file" << EOF
#!/bin/bash
winconfig-redist-it
EOF

    # Ajusta as permissões
    chmod 777 "$drl_file"

# Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$ATALHO" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WinConfig - Windows Game Fix
Exec=winconfig-redist-it
Terminal=false
Categories=Utility;Application;batocera.linux;
Icon=/userdata/system/configs/bat-drl/WindowsGameFix-icon.png
EOF

    # Ajusta as permissões
    chmod 777 "$ATALHO"
    
    # Executa o comando winconfig-redist-lang, se existir
    if command -v winconfig-redist-lang >/dev/null 2>&1; then
        winconfig-redist-lang
    else
        warning "Comando 'winconfig-redist-lang' não encontrado!"
    fi
}

# Comando para instalar o idioma em Francês
frances() {
    # Caminho do arquivo de idioma
    local drl_file="/userdata/roms/ports/- Windows Game Fix.sh"

    # Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$drl_file" << EOF
#!/bin/bash
winconfig-redist-fr
EOF

    # Ajusta as permissões
    chmod 777 "$drl_file"

# Sobrescreve o arquivo com o conteúdo apropriado
    cat > "$ATALHO" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WinConfig - Windows Game Fix
Exec=winconfig-redist-fr
Terminal=false
Categories=Utility;Application;batocera.linux;
Icon=/userdata/system/configs/bat-drl/WindowsGameFix-icon.png
EOF

    # Ajusta as permissões
    chmod 777 "$ATALHO"
    
    # Executa o comando winconfig-redist-lang, se existir
    if command -v winconfig-redist-lang >/dev/null 2>&1; then
        winconfig-redist-lang
    else
        warning "Comando 'winconfig-redist-lang' não encontrado!"
    fi
}

# Script multilíngue de seleção de idioma - by DRL Edition
# Exibe um menu interativo para escolher o idioma e executar comandos
show_menu() {
    clear

    # Data e Hora
    local data=$(date +%d/%m/%Y)
    local hora=$(date +%H:%M:%S)

    echo "========================================="
    echo "         Language Selector - DRL Edition"
    echo "========================================="
    echo "Data / Date / Fecha: $data"
    echo "Hora / Time / Ora / Heure: $hora"
    echo
    echo "Escolha seu idioma / Choose your language / Elige tu idioma / Scegli la lingua / Choisissez votre langue:"
    echo "1: Português Brasil"
    echo "2: English"
    echo "3: Español"
    echo "4: Italiano"
    echo "5: Français"
    echo
    echo "Digite o número e pressione Enter / Type the number and press Enter / Escriba el número y presione Enter / Inserisci il numero e premi Invio / Entrez le numéro et appuyez sur Entrée:"
    read -rp "> " opcao
}

while true; do
    show_menu
    case "$opcao" in
        1)
            echo "Instalando Idioma Português Brasil. Aguarde..."
			clear
            limpargamelist
			clear
            ptbr
			clear
            break
            ;;
        2)
            echo "Installing English language. Please wait..."
			clear
            limpargamelist
			clear
            ingles
			clear
            break
            ;;
        3)
            echo "Instalando idioma Español. Esperar..."
			clear
            limpargamelist
			clear
            espanhol
			clear
            break
            ;;
        4) # Adicionado
            echo "Installazione della lingua Italiana. Aspettare..."
			clear
            limpargamelist
			clear
            italiano
			clear
            break
            ;;
        5) # Adicionado
            echo "Installation de la langue Française. Attendez..."
			clear
            limpargamelist
			clear
            frances
			clear
            break
            ;;
        *)
            echo -e "\nOpção inválida. Tente novamente / Invalid option. Try again. / Opción inválida. Intente nuevamente. / Opzione non valida. Riprova / Option invalide. Essayer à nouveau."
            read -rp "Pressione Enter / Press Enter / Presione Enter / Premi Invio / Appuyez sur Entrée..."
            ;;
    esac
done

# 4. Executar comando `batocera-save-overlay`
clear
echo "Processo concluído com sucesso! / Process completed successfully! / ¡Proceso completado exitosamente! / Processo completato con successo! / Processus terminé avec succès!"

exit 0
