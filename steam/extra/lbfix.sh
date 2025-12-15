#!/usr/bin/env bash

TARGET="/userdata/system/add-ons/steam/.local/share/Steam/ubuntu12_32/steam-runtime/pinned_libs_64/libcurl.so.4"
URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/steam/extra/libcurl.so.4"

echo "[WAIT] Waiting for $TARGET to exist..."

# WAIT UNTIL EXISTS (no !)
while [[ ! -L "$TARGET" && ! -f "$TARGET" ]]; do
    sleep 2
done

echo "[FOUND] $(ls -l "$TARGET")"

if [[ -L "$TARGET" ]]; then
    echo "[SYMLINK DETECTED] Replacing with CURL_OPENSSL_4 safe version..."

    rm -f "$TARGET"
    curl -L -o "$TARGET" "$URL"

    echo "[DONE] New file:"
    ls -l "$TARGET"
else
    echo "[NO SYMLINK] File exists but is not a symlink — nothing to replace."
fi

rm -- "$0"

