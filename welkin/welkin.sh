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
# 国内镜像（可选）：填上直链后会【优先】使用，失败或校验不过就自动回退 GitHub。
# 例：MIRROR_URL="https://你的网盘直链/Welkin_1.0.2_amd64-batocera.AppImage"
MIRROR_URL=""
ASSET="Welkin_${VER}_amd64-batocera.AppImage"
SHA256="beb5c4e0d420f611203be7e10819de87015d448cbc7badc0b0904d7703e4de94"
REL_BASE="${REL%/*}"   # 同一 release 目录下的其它资产
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

echo "== 迁移已有配置（如果之前手动装过，曲库设置不会丢） =="
for d in ".config/com.atemukesu.welkinplayer" ".local/share/com.atemukesu.welkinplayer"; do
    if [ -d "/userdata/system/$d" ] && [ ! -e "$APPDIR/$d" ]; then
        mkdir -p "$(dirname "$APPDIR/$d")"
        cp -a "/userdata/system/$d" "$APPDIR/$d"
        echo "   已迁移 $d"
    fi
done

echo "== 下载 Welkin 自包含构建 =="
download_ok=0
if [ -n "$MIRROR_URL" ]; then
    echo "   先试国内镜像…"
    if curl -fL --retry 3 --retry-delay 2 -C - -o "$APPDIR/${APPNAME}.AppImage" "$MIRROR_URL" 2>/dev/null; then
        download_ok=1
    else
        echo "   镜像不可用，回退 GitHub"
    fi
fi
if [ "$download_ok" != 1 ]; then
    if ! wget -q --show-progress -O "$APPDIR/${APPNAME}.AppImage" "${REL}/${ASSET}"; then
        echo "下载失败：${REL}/${ASSET}"
        echo "（国内网络不稳时：可先用下载工具取回，放到 ${APPDIR}/${APPNAME}.AppImage，"'"'"'"
        echo "  或在脚本顶部把 MIRROR_URL 设成你的直链）"
        exit 1
    fi
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

# 硬件合成默认关闭：包内默认让 WebKit 走软件路径，这是最稳的（无法确认 3D 是否真能用时，
# 打开硬件合成会直接白屏 —— 例如 VMware 会给出 render node 但没有可用的 3D）。
# 确认显卡可用后，创建下面这个文件即可开启（帧率更高）：
#   touch /userdata/system/configs/welkin/use_hw_accel
if [ -e /userdata/system/configs/welkin/use_hw_accel ]; then
    export WELKIN_GL_ACCEL=1
fi

LOG="$LOGS_DIR/welkin.log"
mkdir -p "\$(dirname "\$LOG")"
echo "\$(date): 启动 Welkin" >> "\$LOG"

cd "$APPDIR" || exit 1

# 关键：必须在自己的 session bus 里启动。
# 实测（Batocera 43.1）：HOME 指向附加组件目录时，如果没有 session bus，
# WebKit 会渲染成纯白屏；套 dbus-run-session 即恢复正常。
if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session -- ./${APPNAME}.AppImage --no-sandbox "\$@" >> "\$LOG" 2>&1
else
    exec ./${APPNAME}.AppImage --no-sandbox "\$@" >> "\$LOG" 2>&1
fi
EOF
chmod +x "$PORTS_DIR/${APPNAME}.sh"

echo "== 取图标 =="
# 优先用发布资产（一定存在），失败再退回本仓库 welkin/extra/
get_icon() {   # $1=目标路径  $2=发布资产名  $3=仓库内文件名
    wget -q -O "$1" "${REL_BASE}/$2" || wget -q -O "$1" "${RAW_BASE}/$3" || rm -f "$1"
    [ -s "$1" ] || echo "   警告：$3 取不到（不影响使用）"
}
get_icon "$APPDIR/extra/icon.png"            addon-icon.png icon.png
get_icon "$PORTS_DIR/images/welkin-logo.png" addon-logo.png welkin-logo.png

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
# Batocera 不自带 xmlstarlet（BUA 的安装器 app 会装），这里用 python3 兜底
gamelist_add() {
    if command -v xmlstarlet >/dev/null 2>&1; then
        if grep -q "\./${APPNAME}.sh" "$GAME_LIST"; then
            echo "   gamelist.xml 里已有条目，跳过"; return 0
        fi
        xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
          -s "/gameList/game[last()]" -t elem -n "path" -v "./${APPNAME}.sh" \
          -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
          -s "/gameList/game[last()]" -t elem -n "image" -v "./images/welkin-logo.png" \
          "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"
    else
        python3 - "$GAME_LIST" "$APPNAME" <<'PYEOF'
import sys, xml.etree.ElementTree as ET
path, name = sys.argv[1], sys.argv[2]
tree = ET.parse(path); root = tree.getroot()
want = "./%s.sh" % name
for g in root.findall("game"):
    if (g.findtext("path") or "") == want:
        print("   gamelist.xml 里已有条目，跳过"); raise SystemExit(0)
g = ET.SubElement(root, "game")
ET.SubElement(g, "path").text = want
ET.SubElement(g, "name").text = name
ET.SubElement(g, "image").text = "./images/welkin-logo.png"
tree.write(path, encoding="utf-8", xml_declaration=True)
print("   已用 python3 写入 gamelist.xml")
PYEOF
    fi
}
gamelist_add

echo "== 刷新 Ports 菜单 =="
curl -s http://127.0.0.1:1234/reloadgames > /dev/null 2>&1 || true

echo
echo "安装完成！在 Ports 菜单里选 «Welkin» 即可启动。"
echo "  - Escape：退出回 EmulationStation"
echo "  - 侧栏「可视化」（在「全部曲目」与「歌手」之间）：选效果后进全屏可视化"
echo "  - 想开硬件合成（帧率更高）：touch /userdata/system/configs/welkin/use_hw_accel"
echo
