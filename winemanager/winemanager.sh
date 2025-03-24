#!/bin/bash

# Mensagem de boas-vindas
echo "Seja bem vindo ao instalador automático do Wine Manager by DRL Edition."

# Diretório temporário para download
TEMP_DIR="/userdata/tmp/winemanager"
DRL_FILE="$TEMP_DIR/winemanager.zip"
DEST_DIR="/userdata/"

# Cria o diretório temporário
echo "Criando diretório temporário para download..."
mkdir -p $TEMP_DIR

# Faz o download do arquivo drl 
echo "Fazendo download do arquivo winemanager.drl..."
curl -L -o $DRL_FILE "https://github.com/DRLEdition19/batocera-unofficial-addons.add/raw/refs/heads/main/winemanager/extra/winemanager.zip"

# Extrai o arquivo drl com barra de progresso e altera permissões de cada arquivo extraído
echo "Extraindo o arquivo drl e definindo permissões para cada arquivo..."
unzip -o $DRL_FILE -d $TEMP_DIR | while IFS= read -r file; do
    if [ -f "$TEMP_DIR/$file" ]; then
        chmod 777 "$TEMP_DIR/$file"
    fi
done

# Copia os arquivos extraídos para o diretório raiz, substituindo os existentes
echo "Copiando arquivos extraídos para o diretório raiz..."
cp -r $TEMP_DIR/* $DEST_DIR

# Limpa o diretório temporário
echo "Limpando diretório temporário..."
rm -rf $TEMP_DIR

# Exclui o arquivo winemanager.drl do diretório raiz
echo "Excluindo o arquivo winemanager.drl do diretório raiz..."
rm -f /userdata/winemanager.zip

echo "Instalação concluída com sucesso."
