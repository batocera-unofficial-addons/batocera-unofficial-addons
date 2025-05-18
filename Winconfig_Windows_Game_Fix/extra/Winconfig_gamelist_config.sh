#!/bin/bash

# Definição das variáveis
TARGET_DIR="/userdata/roms/ports"
TARGET_FILE="gamelist.xml"
FILE_PATH="$TARGET_DIR/$TARGET_FILE"
TEMP_FILE=$(mktemp) || { echo "Erro ao criar arquivo temporário."; exit 1; }

# Função para limpar o arquivo temporário na saída
cleanup() {
  rm -f "$TEMP_FILE"
}
trap cleanup EXIT # Registra a função cleanup para ser executada ao sair do script

# Conteúdo a ser adicionado/inserido
# Usando 'EOF' entre aspas simples para prevenir expansão de variáveis e substituição de comandos dentro do heredoc
read -r -d '' GAME_ENTRY <<'EOF'
		<game>
		<path>./- Windows Game Fix.sh</path>
		<name>- Windows Game Fix on Batocera</name>
		<desc>This script, known as the "Windows Game Manager for Batocera - by DRL Edition", is designed to simplify the configuration and management of Windows games within the Batocera operating system.
This tool, known as "Winconfig - Windows Game Fix - by DRL Edition", was developed to simplify the configuration and management of Windows games on the Batocera operating system.

Its main features include:

-> Extracting games from various compressed formats (such as .zip, .rar, .wsquashfs, .plus).
-> Compressing game folders to save space.
-> Automatic creation of the necessary startup files (autorun.cmd, batocera.plus) for Batocera.
-> Automatic renaming of game folders with appropriate suffixes (.pc, .wine, .plus) for compatibility with Batocera.
-> Automatic backups of original game folders before modifications, if the user enables this option in the settings menu.
-> Restoring games from these backups. 
-> A "Redist" tool to install crucial Windows dependencies (such as DirectX, VC Runtimes) into the game environment to improve compatibility.
-> An interactive settings panel to customize ROM directories, AntiMicroX profiles, compression settings, registries, and more.
-> Checking for required system dependencies if the user enables this option in the settings menu.
-> Providing a comprehensive interactive help manual.
-> Providing direct access to AntiMicroX for gamepad mapping configuration.

=================================================

The project was based on an initiative started by DRL Edition on 2023-01-22, and this version of the script was last updated on 2025-04-25.

=================================================
    Last updated: 04/25/2025
    Developer: DRL Edition19
    Redist, 2025 by DRL Edition
=================================================</desc>
		<image>./images/WindowsGameFix-thumb.png</image>
		<marquee>./images/WindowsGameFix-marquee.png</marquee>
		<thumbnail>./images/WindowsGameFix-thumb.png</thumbnail>
		<fanart>./images/WindowsGameFix-thumb.png</fanart>
		<titleshot>./images/WindowsGameFix-thumb.png</titleshot>
		<cartridge>./images/WindowsGameFix-thumb.png</cartridge>
		<boxart>./images/WindowsGameFix-marquee.png</boxart>
		<boxback>./images/WindowsGameFix-thumb.png</boxback>
		<wheel>./images/WindowsGameFix-thumb.png</wheel>
		<mix>./images/WindowsGameFix-thumb.png</mix>
		<rating>1</rating>
		<releasedate>20230122T220656</releasedate>
		<developer>DRL Edition</developer>
		<publisher>DRLEdition19</publisher>
		<genre>Game Fix</genre>
		<players>1</players>
		<favorite>true</favorite>
		<lang>en</lang>
		<region>Conceicao de Cima, Alagoinhas, Bahia, Brazil</region>
		<sortname>1 =-  Windows Game Fix</sortname>
		<genreid>0</genreid>
		<screenshot>./images/WindowsGameFix-thumb.png</screenshot>
	</game>
EOF

# Conteúdo completo para um arquivo novo ou vazio
# Usando 'EOF' entre aspas simples
read -r -d '' FULL_CONTENT <<EOF
<?xml version="1.0"?>
<gameList>
${GAME_ENTRY}
</gameList>
EOF

# --- Início da Lógica ---

echo "Verificando diretório $TARGET_DIR..."
# Cria o diretório se não existir (-p evita erro se já existir e cria pais)
mkdir -p "$TARGET_DIR" || { echo "Erro ao criar diretório $TARGET_DIR."; exit 1; }
echo "Diretório verificado/criado com sucesso."

# Verifica se o arquivo existe e NÃO está vazio
if [ -f "$FILE_PATH" ] && [ -s "$FILE_PATH" ]; then
    echo "Arquivo $FILE_PATH encontrado."

    # Verifica se o cabeçalho e a tag <gameList> existem
    # Usando grep -q para não exibir a saída e -F para tratar como string fixa
    # Verificando as duas linhas separadamente para mais flexibilidade
    if grep -qF '<?xml version="1.0"?>' "$FILE_PATH" && grep -q '<gameList>' "$FILE_PATH"; then
        echo "Cabeçalho XML e tag <gameList> encontrados."

        # Verifica se a entrada específica do jogo já existe para evitar duplicação
        if grep -qF '<path>./- Windows Game Fix.sh</path>' "$FILE_PATH"; then
            echo "A entrada para '- Windows Game Fix.sh' já existe. Nenhuma alteração necessária."
        else
            echo "Adicionando a entrada para '- Windows Game Fix.sh'..."
            # Usa awk para inserir o GAME_ENTRY após a linha que contém <gameList>
            # Isso é mais robusto do que sed para inserções multi-linha
            awk -v game_entry="$GAME_ENTRY" '
            /<\s*gameList\s*>/ {
                print # Imprime a linha <gameList>
                print game_entry # Imprime a nova entrada do jogo
                next # Pula para a próxima linha sem executar a ação padrão de impressão
            }
            { print } # Imprime todas as outras linhas
            ' "$FILE_PATH" > "$TEMP_FILE"

            # Verifica se o awk foi executado com sucesso
            if [ $? -eq 0 ]; then
                # Move o arquivo temporário para o original
                mv "$TEMP_FILE" "$FILE_PATH"
                if [ $? -eq 0 ]; then
                    echo "Entrada do jogo adicionada com sucesso em $FILE_PATH."
                else
                    echo "Erro ao mover o arquivo temporário para $FILE_PATH."
                    exit 1
                fi
            else
                echo "Erro ao processar o arquivo com awk."
                # Não removemos $TEMP_FILE aqui porque o trap fará isso
                exit 1
            fi
        fi
    else
        echo "Aviso: O arquivo $FILE_PATH existe mas não contém o cabeçalho esperado ('<?xml version=\"1.0\"?>' e '<gameList>')."
        echo "Considerando como arquivo mal formatado ou vazio e sobrescrevendo com a estrutura completa."
        echo "$FULL_CONTENT" > "$FILE_PATH"
        if [ $? -eq 0 ]; then
            echo "Arquivo $FILE_PATH sobrescrito com a estrutura padrão."
        else
            echo "Erro ao sobrescrever $FILE_PATH."
            exit 1
        fi
    fi
else
    # O arquivo não existe ou está vazio
    if [ ! -f "$FILE_PATH" ]; then
        echo "Arquivo $FILE_PATH não encontrado. Criando novo arquivo..."
    else
        echo "Arquivo $FILE_PATH está vazio. Criando estrutura padrão..."
    fi

    # Cria o arquivo com o conteúdo completo
    echo "$FULL_CONTENT" > "$FILE_PATH"
    if [ $? -eq 0 ]; then
        echo "Arquivo $FILE_PATH criado com sucesso com a estrutura padrão."
    else
        echo "Erro ao criar o arquivo $FILE_PATH."
        exit 1
    fi
fi

# Aplica as permissões
echo "Aplicando permissões (chmod 777) para $FILE_PATH..."
chmod 777 "$FILE_PATH" || { echo "Erro ao aplicar permissões em $FILE_PATH."; exit 1; }
echo "Permissões aplicadas com sucesso."

echo "Script concluído."

exit 0
