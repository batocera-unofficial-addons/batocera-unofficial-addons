#!/bin/bash

# Diretório onde os executáveis serão armazenados
WINE_EXE_DIR="/userdata/system/wine/exe"

# Criar o diretório se não existir
mkdir -p "$WINE_EXE_DIR"

# Função para baixar e extrair arquivos
download_and_extract() {
    local url=$1
    local output_dir=$2
    local filename=$(basename "$url")
    
    # Baixar o arquivo
    wget -P "$output_dir" "$url"
    
    # Se for um arquivo .7z, extrair
    if [[ "$filename" == *.7z ]]; then
        7zr x "$output_dir/$filename" -o"$output_dir"
        rm "$output_dir/$filename"
    fi
}

# Baixar e extrair DirectX3D
echo "Baixando e extraindo DirectX3D..."
download_and_extract "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/directx.7z" "$WINE_EXE_DIR"

# Baixar Visual C++ Redistributable 2015-2019
echo "Baixando Visual C++ Redistributable 2015-2019..."
wget -P "$WINE_EXE_DIR" "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/vcredist_x64_2015_2019.exe"

# Baixar Visual C++ Redistributable 2019
echo "Baixando Visual C++ Redistributable 2019..."
wget -P "$WINE_EXE_DIR" "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/vcredist_x64_2019.exe"

# Baixar Visual C++ Redistributable 2017
echo "Baixando Visual C++ Redistributable 2017..."
wget -P "$WINE_EXE_DIR" "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/vcredist_x64_2017.exe"

# Baixar Visual C++ Redistributable 2015
echo "Baixando Visual C++ Redistributable 2015..."
wget -P "$WINE_EXE_DIR" "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/vcredist_x64_2015.exe"

# Baixar Visual C++ Redistributable 2013
echo "Baixando Visual C++ Redistributable 2013..."
wget -P "$WINE_EXE_DIR" "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/vcredist_x64_2013.exe"

# Baixar Visual C++ Redistributable 2012
echo "Baixando Visual C++ Redistributable 2012..."
wget -P "$WINE_EXE_DIR" "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/vcredist_x64_2012.exe"

# Baixar Visual C++ Redistributable 2010
echo "Baixando Visual C++ Redistributable 2010..."
wget -P "$WINE_EXE_DIR" "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/vcredist_x64_2010.exe"

# Baixar Visual C++ Redistributable 2008
echo "Baixando Visual C++ Redistributable 2008..."
wget -P "$WINE_EXE_DIR" "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/vcredist_x64_2008.exe"

# Baixar Visual C++ Redistributable 2005
echo "Baixando Visual C++ Redistributable 2005..."
wget -P "$WINE_EXE_DIR" "https://github.com/DRLEdition19/batocera.drl/releases/download/Batocera_Appimages/vcredist_x64_2005.exe"

echo "Todos os arquivos foram baixados e extraídos para $WINE_EXE_DIR."