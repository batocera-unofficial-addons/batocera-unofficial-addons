#!/bin/bash

WINE_EXE_DIR="/userdata/system/wine/exe"

mkdir -p "$WINE_EXE_DIR"

download() {
    local name=$1
    local url=$2
    echo "Downloading $name..."
    if ! wget -q --show-progress -O "$WINE_EXE_DIR/$name" "$url"; then
        echo "ERROR: Failed to download $name"
        exit 1
    fi
}

download "directx_Jun2010_redist.exe" \
    "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe"

download "vcredist_x64_2005.exe" \
    "https://download.microsoft.com/download/6/b/b/6bb661d6-a8ae-4819-b79f-236472f6070c/vcredist_x64.exe"

download "vcredist_x64_2008.exe" \
    "https://download.microsoft.com/download/5/d/8/5d8c65cb-c849-4025-8e95-c3966cafd8ae/vcredist_x64.exe"

download "vcredist_x64_2010.exe" \
    "https://download.microsoft.com/download/1/6/5/165255e7-1014-4d0a-b094-b6a430a6bffc/vcredist_x64.exe"

download "vcredist_x64_2012.exe" \
    "https://download.microsoft.com/download/1/6/b/16b06f60-3b20-4ff2-b699-5e9b7962f9ae/VSU_4/vcredist_x64.exe"

download "vcredist_x64_2013.exe" \
    "https://download.microsoft.com/download/2/e/6/2e61cfa4-993b-4dd4-91da-3737cd5cd6e3/vcredist_x64.exe"

download "vcredist_x64_2015.exe" \
    "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe"

download "vcredist_x64_2017.exe" \
    "https://aka.ms/vs/15/release/vc_redist.x64.exe"

download "vcredist_x64_2019.exe" \
    "https://aka.ms/vs/16/release/vc_redist.x64.exe"

download "vcredist_x64_2015_2019.exe" \
    "https://aka.ms/vs/17/release/vc_redist.x64.exe"

echo "All files downloaded to $WINE_EXE_DIR."
