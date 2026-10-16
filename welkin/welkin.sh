#!/bin/bash
###############################################################################
#  Welkin — Batocera 非官方附加组件安装脚本
#
#  为什么不用上游官方 AppImage：
#    上游 v1.0.2 的 AppImage 是「旧架构」（webview + GStreamer）打包的，包内只有
#    GStreamer 核心库、零插件，在 Batocera 上一播放就崩 / 没声音。这里安装的是
#    「上游源码 + 两个补丁」重编的自包含构建：
#      - 新版播放走 rodio + symphonia（Rust 内部解码），不需要任何插件闭包
#      - Escape 退出（kiosk 习惯，回 EmulationStation）
#      - 全屏音频可视化（侧栏「可视化」→ 选效果 → 开始全屏）
#    这两个补丁已作为 PR 提给上游：https://github.com/atemukesu/WelkinPlayer/pull/3
###############################################################################
set -u

APPNAME="Welkin"
VER="1.0.2"
REL="https://github.com/anturong/WelkinPlayer/releases/download/batocera-${VER}-r3"
ASSET="Welkin_${VER}_amd64-batocera.AppImage"
SHA256="beb5c4e0d420f611203be7e10819de87015d448cbc7badc0b0904d7703e4de94"
RAW_BASE="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/welkin/extra"

ADDONS_DIR="/userdata/system/add-ons"
APPDIR="${ADDONS_DIR}/welkin"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="${PORTS_DIR}/gamelist.xml"
CONF_DIR="/userdata/system/configs/welkin"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="${CONF_DIR}/${APPNAME}.desktop"
RESTORE_SCRIPT="${CONF_DIR}/restore_desktop_entry.sh"

echo "== 检查架构 =="
arch="$(uname -m)"
if [ "$arch" != "x86_64" ]; then
    echo "目前只提供 x86_64 构建（当前：$arch）。"
    exit 1
fi

echo "== 建立目录 =="
mkdir -p "$APPDIR/extra" "$PORTS_DIR/images" "$LOGS_DIR" "$CONF_DIR"

echo "== 下载 Welkin 自包含构建 =="
if ! wget -q --show-progress -O "$APPDIR/${APPNAME}.AppImage" "${REL}/${ASSET}"; then
    echo "下载失败：${REL}/${ASSET}"
    echo "（国内网络不稳时可先用下载工具取回，再放到 ${APPDIR}/${APPNAME}.AppImage）"
    exit 1
fi

echo "== 校验 sha256 =="
got="$(sha256sum "$APPDIR/${APPNAME}.AppImage" | awk '{print $1}')"
if [ "$got" != "$SHA256" ]; then
    echo "sha256 不匹配！"
    echo "  期望：$SHA256"
    echo "  实际：$got"
    echo "（下载被截断时会出现这种情况，重跑一次即可）"
    exit 1
fi
chmod a+x "$APPDIR/${APPNAME}.AppImage"
echo "   校验通过：$got"

echo "== 写 Ports 启动器 =="
cat << EOF > "$PORTS_DIR/${APPNAME}.sh"
#!/bin/bash
# 由 Welkin 附加组件安装脚本生成
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="$APPDIR"

# Batocera 习惯：Escape 退出回 EmulationStation
export WELKIN_ESC_QUITS=1

# 音频（PipeWire/PulseAudio）需要
if [ -z "\${XDG_RUNTIME_DIR:-}" ] || [ ! -d "\${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR=/var/run
fi

# 有可用 GPU 时让 WebKit 走硬件合成（帧率更高）；没有就自动走软件路径
if [ -e /dev/dri/renderD128 ]; then
    export WELKIN_GL_ACCEL=1
fi

LOG="$LOGS_DIR/welkin.log"
mkdir -p "\$(dirname "\$LOG")"
echo "\$(date): 启动 Welkin" >> "\$LOG"

cd "$APPDIR" || exit 1
exec ./${APPNAME}.AppImage --no-sandbox "\$@" >> "\$LOG" 2>&1
EOF
chmod +x "$PORTS_DIR/${APPNAME}.sh"

echo "== 取图标 =="
wget -q -O "$APPDIR/extra/icon.png"        "${RAW_BASE}/icon.png"        || true
wget -q -O "$PORTS_DIR/images/welkin-logo.png" "${RAW_BASE}/welkin-logo.png" || true

echo "== 写持久化 desktop entry（/usr/share 会被系统更新覆盖，所以留一份并自愈） =="
cat << EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APPNAME}
Comment=本地音乐播放器（含全屏可视化）
Exec=${PORTS_DIR}/${APPNAME}.sh
Icon=$APPDIR/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF
chmod +x "$PERSISTENT_DESKTOP"
cp -f "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

cat << EOF > "$RESTORE_SCRIPT"
#!/bin/bash
# 系统更新会清掉 /usr/share/applications，这里在开机时补回来
if [ ! -f "$DESKTOP_FILE" ]; then
    cp -f "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
fi
EOF
chmod +x "$RESTORE_SCRIPT"

CUSTOM_STARTUP="/userdata/system/custom.sh"
touch "$CUSTOM_STARTUP"
if ! grep -q "$RESTORE_SCRIPT" "$CUSTOM_STARTUP"; then
    echo "bash \"$RESTORE_SCRIPT\" &" >> "$CUSTOM_STARTUP"
fi
chmod +x "$CUSTOM_STARTUP"

echo "== 加入 Ports 列表 =="
if [ ! -f "$GAME_LIST" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$GAME_LIST"
fi
if grep -q "\./${APPNAME}.sh" "$GAME_LIST"; then
    echo "   gamelist.xml 里已有条目，跳过（重复运行不会产生重复项）"
else
    xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
      -s "/gameList/game[last()]" -t elem -n "path" -v "./${APPNAME}.sh" \
      -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
      -s "/gameList/game[last()]" -t elem -n "image" -v "./images/welkin-logo.png" \
      "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"
fi

echo "== 刷新 Ports 菜单 =="
curl -s http://127.0.0.1:1234/reloadgames > /dev/null 2>&1 || true

echo
echo "安装完成！在 Ports 菜单里选 «Welkin» 即可启动。"
echo "  - Escape：退出回 EmulationStation"
echo "  - 侧栏「可视化」（在「全部曲目」与「歌手」之间）：选效果后进全屏可视化"
echo
