#!/bin/bash
# BUA Steam boot-time ensure: add steam.emulator=sh and steam.core=sh if missing.
# Batocera system updates (e.g. v42→v43) can overwrite batocera.conf and drop
# steam.* entries—games then fail. This script re-adds them on boot when absent.
# Idempotent: if already present, exits immediately. Zero impact when config intact.
BUA_STEAM="/userdata/system/add-ons/steam"
BATOCERA_CONF="/userdata/system/batocera.conf"

[ ! -d "$BUA_STEAM" ] && exit 0
[ ! -f "$BATOCERA_CONF" ] && exit 0
grep -q "^steam\.emulator=" "$BATOCERA_CONF" 2>/dev/null && exit 0

sed -i '/^steam\.emulator=/d; /^steam\.core=/d' "$BATOCERA_CONF" 2>/dev/null || true
echo "steam.emulator=sh" >> "$BATOCERA_CONF"
echo "steam.core=sh" >> "$BATOCERA_CONF"
