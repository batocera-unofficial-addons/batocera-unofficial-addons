#!/bin/bash
# Uninstaller for Overlay Remove, installed by overlay-remove.sh.
# overlay-remove.sh installs nothing: it deletes /boot/boot/overlay (the saved
# changes to Batocera's system files) and exits. A deleted overlay can't be
# brought back, so there is nothing to remove or restore here. This script
# exists so the BUA app can drop Overlay Remove from its installed list.

APP_NAME="Overlay Remove"

echo "${APP_NAME} installs no files, so there is nothing to remove."
echo "An overlay it already deleted can't be restored."
exit 0
