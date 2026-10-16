#!/bin/bash
###############################################################################
#  Welkin — 附加组件卸载脚本
###############################################################################
set -u
APPNAME="Welkin"
APPDIR="/userdata/system/add-ons/welkin"
PORTS_DIR="/userdata/roms/ports"
GAME_LIST="${PORTS_DIR}/gamelist.xml"
CONF_DIR="/userdata/system/configs/welkin"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
CUSTOM_STARTUP="/userdata/system/custom.sh"

echo "== 停止正在运行的 Welkin =="
pkill -f welkinplayer 2>/dev/null
sleep 1

echo "== 删除启动器与条目 =="
rm -f "$PORTS_DIR/${APPNAME}.sh" "$PORTS_DIR/images/welkin-logo.png"
rm -f "$DESKTOP_FILE" "${CONF_DIR}/${APPNAME}.desktop" "${CONF_DIR}/restore_desktop_entry.sh"
rmdir "$CONF_DIR" 2>/dev/null || true

if [ -f "$GAME_LIST" ]; then
    xmlstarlet ed -d "/gameList/game[path='./${APPNAME}.sh']" "$GAME_LIST" > "$GAME_LIST.tmp" \
        && mv "$GAME_LIST.tmp" "$GAME_LIST"
fi

if [ -f "$CUSTOM_STARTUP" ]; then
    sed -i "\|${CONF_DIR}/restore_desktop_entry.sh|d" "$CUSTOM_STARTUP"
fi

echo "== 删除程序文件 =="
rm -rf "$APPDIR"

echo "== 刷新 Ports 菜单 =="
curl -s http://127.0.0.1:1234/reloadgames > /dev/null 2>&1 || true

echo
echo "卸载完成。日志保留在 /userdata/system/logs/welkin.log（如需清理可自行删除）。"
