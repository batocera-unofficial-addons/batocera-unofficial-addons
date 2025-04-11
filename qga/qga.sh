#!/bin/bash

# Download and extract the addon
curl -L https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/qga/extra/qga.tar.gz | tar -xz -C /userdata/system/add-ons

# Create the service script
cat << 'EOF' > /userdata/system/services/qemu_ga
#!/bin/bash

QGA_BIN="/usr/bin/qemu-ga"
QGA_PID="/userdata/system/add-ons/qga/qga.pid"

start() {
  # Wait silently for /usr/bin/qemu-ga to become available
  timeout=30
  elapsed=0

  while [[ ! -x "$QGA_BIN" && $elapsed -lt $timeout ]]; do
    sleep 1
    ((elapsed++))
  done

  if [[ ! -x "$QGA_BIN" ]]; then
    exit 1
  fi

  if [[ -z "$(pidof qemu-ga)" ]]; then
    echo "Starting QEMU Guest Agent..."
    nohup "$QGA_BIN" -d -v --pidfile="$QGA_PID" >/dev/null 2>&1 &
  else
    echo "QEMU Guest Agent is already running."
  fi
}

stop() {
  echo "Stopping QEMU Guest Agent..."
  if [[ -f "$QGA_PID" ]]; then
    kill "$(cat "$QGA_PID")" && rm -f "$QGA_PID"
  else
    pkill -f qemu-ga
  fi
}

restart() {
  stop
  sleep 1
  start
}

status() {
  if pidof qemu-ga >/dev/null; then
    echo "QEMU Guest Agent is running (PID: $(pidof qemu-ga))."
  else
    echo "QEMU Guest Agent is not running."
  fi
}

case "$1" in
  start)
    start &
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  status)
    status
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
EOF

# Make the service script executable
chmod +x /userdata/system/services/qemu_ga

# Wait silently for /usr/bin/qemu-ga to become available
timeout=30
elapsed=0

while [[ ! -x /usr/bin/qemu-ga && $elapsed -lt $timeout ]]; do
    sleep 1
    ((elapsed++))
done

if [[ ! -x /usr/bin/qemu-ga ]]; then
    exit 1
fi

batocera-services enable qemu_ga
batocera-services start qemu_ga &>/dev/null &

clear_
dialog --msgbox "QEMU Guest Agent installed and service created!\n\nTo manually control it, use:\n\nbatocera-services {start|stop|restart} qemu_ga" 10 60
clear
exit 0
