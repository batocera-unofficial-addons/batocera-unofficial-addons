#!/bin/bash

# Set variables
APP_NAME="F1"
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/f1/extra/f1key.jpg"   # Replace with actual logo URL
LOGO_PATH="/userdata/roms/ports/images/${APP_NAME,,}-logo.jpg"
GAME_LIST="/userdata/roms/ports/gamelist.xml"

# Step 1: Create the launcher script
echo "Creating ${APP_NAME}.sh..."
cat << 'EOF' > "/userdata/roms/ports/${APP_NAME}.sh"
#!/bin/bash

export XDG_MENU_PREFIX=batocera-
export XDG_CONFIG_DIRS=/etc/xdg
ANTIMICROX_PROFILE="/userdata/system/configs/bat-drl/Nav_Redist2.joystick.amgp"

# fix for exfat on HOME + pcmanfm
export XDG_CACHE_HOME=/tmp/xdg_cache
ANTIMICROX_PROFILE="/userdata/system/configs/bat-drl/Nav_Redist2.joystick.amgp"

# Fix xterm via F4 is not previously set up
python << EOF
import configparser
F = '/userdata/system/.config/libfm/libfm.conf'
c = configparser.ConfigParser()
c.read(F)
try:
   t = c['config']['terminal']
except:
   t = None
if (not t or t == ''):
   with open(F, 'w') as wf:
     c['config']['terminal'] = 'xterm'
     c.write(wf)
EOF

### Inicia o AntiMicroX ###
    if [ -e '/dev/input/js0' ]; then
        antimicrox --hidden --profile "$ANTIMICROX_PROFILE" &
        ANTIMICROX_PID=$!
        success "AntiMicroX iniciado (PID: $ANTIMICROX_PID)"
    else
        warning "Nenhum joystick detectado"
    fi

### Inicia o desktop e o pcmanfm ###
batocera-mouse show
DISPLAY=${DISPLAY:-:0.0} pcmanfm /userdata
batocera-mouse hide

### Encerra o AntiMicroX, o desktop e o pcmanfm ###
    if [ -n "${ANTIMICROX_PID}" ]; then
        kill -9 "${ANTIMICROX_PID}" 2>/dev/null
        pkill -9 "${ANTIMICROX_PID}" 2>/dev/null
    fi
    
exit 0
EOF

chmod +x "${APP_NAME}.sh"

# Step 2: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl -s http://127.0.0.1:1234/reloadgames

# Step 3: Download the logo
echo "Downloading logo..."
curl -s -L -o "$LOGO_PATH" "$LOGO_URL"

# Step 4: Add entry to gamelist.xml
echo "Adding $APP_NAME to gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME,,}-logo.jpg" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"

# Step 5: Final refresh
curl -s http://127.0.0.1:1234/reloadgames

echo "Done! ${APP_NAME} has been added."
