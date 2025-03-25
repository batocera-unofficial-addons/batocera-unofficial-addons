#!/bin/bash

APPNAME="DOS Game Builder"
LOG_FILE="/tmp/docker_dos_game_build.log"
DOCKER_IMAGE="magicalyak/docker-games"

# Array format: TAG|URL|ARGS|DIR|DOCKERFILE
games=(
  "scorch|https://archive.org/download/msdos_festival_SCORCH15/SCORCH15.ZIP|SCORCH.EXE||Dockerfile"
  "secretagent|https://archive.org/download/SecretAgent_945/AGENT.ZIP|SAM1.EXE||Dockerfile"
  "cosmo|https://archive.org/download/CosmosCosmicAdventure/CosmosCosmicAdventure-ForbiddenPlanet-Adventure1Of3V1.20sw1992apogeeSoftwareLtd.action.zip|COSMO1.EXE||Dockerfile"
  "doom|https://archive.org/download/DoomsharewareEpisode/doom.ZIP|DOOM.EXE||Dockerfile"
  "keen|https://image.dosgamesarchive.com/games/keen-shr.zip|KEEN.BAT||Dockerfile"
  "simcity|https://archive.org/download/msdos_SimCity_Classic_1994/SimCity_Classic_1994.zip|SIMCITY.EXE|SimCityC|Dockerfile.2"
  "simcity2000|https://archive.org/download/SimCity-2/simcity2000.zip|SC2000.EXE||Dockerfile"
  "colossalcave|https://archive.org/download/ColossalCave1984WillieCrowtherJerryD.PohlAdventureInteractiveFiction/ColossalCave.zip|COLOSSAL.EXE||Dockerfile"
  "civilization|https://archive.org/download/msdos_sid_meier_civilization/Civilizations.zip|CIV.BAT||Dockerfile"
  "spacequest4|https://archive.org/download/msdos_Space_Quest_IV_-_Roger_Wilco_and_the_Time_Rippers_1991/Space_Quest_IV_-_Roger_Wilco_and_the_Time_Rippers_1991.zip|SQ4.BAT|SQ4|Dockerfile.2"
  "kingsquest5|https://archive.org/download/msdos_Kings_Quest_V_-_Absence_Makes_the_Heart_Go_Yonder_1990/Kings_Quest_V_-_Absence_Makes_the_Heart_Go_Yonder_1990.zip|SIERRA.EXE|KQ5|Dockerfile.2"
  "kingsquest6|https://archive.org/download/msdos_Kings_Quest_VI_-_Heir_Today_Gone_Tomorrow_1992/Kings_Quest_VI_-_Heir_Today_Gone_Tomorrow_1992.zip|KQ6CD.BAT|KQ6CD|Dockerfile.2"
  "kingsquest7|https://archive.org/download/msdos_Kings_Quest_VII_-_The_Princeless_Bride_1994/Kings_Quest_VII_-_The_Princeless_Bride_1994.zip|KQ7.BAT|KQ7|Dockerfile.2"
  "monkeyisland|https://archive.org/download/monkey_dos/MONKEY.zip|MONKEY.EXE||Dockerfile"
  "battlechess|https://archive.org/download/battle_chess_1988/battle_chess.zip|CHESS.EXE||Dockerfile"
  "TMNT|https://archive.org/download/tmnt_dos/TURTLES.zip|TURTLES.EXE||Dockerfile"
  "oregontrail|https://archive.org/download/oregon-trail-deluxe/Oregon%20Trail%20Deluxe.zip|OREGON.EXE||Dockerfile"
)

# Build dialog menu
menu_items=()
i=1
for entry in "${games[@]}"; do
  IFS="|" read -r tag _ _ _ _ <<< "$entry"
  menu_items+=("$i" "$tag")
  i=$((i+1))
done
menu_items+=("$i" "Exit")

while true; do
  choice=$(dialog --clear --backtitle "$APPNAME" \
    --title "Select a game to build" \
    --menu "Choose a game from the list:" 20 60 15 \
    "${menu_items[@]}" \
    3>&1 1>&2 2>&3)

  if [[ "$choice" == "$i" || -z "$choice" ]]; then
    clear
    echo "Exited."
    exit 0
  fi

  entry="${games[$((choice - 1))]}"
  IFS="|" read -r GAME_TAG GAME_URL GAME_ARGS GAME_DIR DOCKERFILE <<< "$entry"

  # Default Dockerfile fallback
  DOCKERFILE="${DOCKERFILE:-Dockerfile}"

  MSG="Building $DOCKER_IMAGE:$GAME_TAG using $DOCKERFILE"
  dialog --title "$APPNAME" --infobox "$MSG" 8 50

  # Build command
  build_cmd=(
    docker build --no-cache
    --build-arg GAME_URL="$GAME_URL"
    --build-arg GAME_ARGS="\"$GAME_ARGS\""
    -t "$DOCKER_IMAGE:$GAME_TAG"
  )

  [ -n "$GAME_DIR" ] && build_cmd+=(--build-arg GAME_DIR="$GAME_DIR")
  [ "$DOCKERFILE" != "Dockerfile" ] && build_cmd+=(-f "$DOCKERFILE")

  build_cmd+=(.)

  # Run the build
  "${build_cmd[@]}" &> "$LOG_FILE"

  if [[ $? -eq 0 ]]; then
    RESULT="✅ $GAME_TAG built successfully!\nImage: $DOCKER_IMAGE:$GAME_TAG"
  else
    RESULT="❌ Build failed for $GAME_TAG.\nCheck: $LOG_FILE"
  fi

  dialog --title "$APPNAME" --msgbox "$RESULT" 10 60
done
