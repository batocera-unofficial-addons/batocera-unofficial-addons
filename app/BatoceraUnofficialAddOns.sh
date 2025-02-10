#!/bin/bash
DIALOGRC=/userdata/system/add-ons/.dialogrc DISPLAY=:0.0 xterm -fs 20 -maximized -fg white -bg black -fa "DejaVuSansMono" -en UTF-8 -e bash -c "DISPLAY=:0.0  curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/batocera-unofficial-addons.sh | bash"

