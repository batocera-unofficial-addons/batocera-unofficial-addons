#!/bin/bash

# Download and extract the addon
curl -L https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/qga/extra/qga.tar.gz | tar -xz -C /userdata/system/add-ons

# Create the service script
cat << 'EOF' > /userdata/system/services/qemu-ga
#!/bin/bash

QGA_PID="/userdata/system/add-ons/qga/qga.pid"

start() {
  if [[ -z "$(pidof qemu-ga)" ]]; then
    echo "Starting QEMU Guest Agent..."
    nohup qemu-ga -d -v --pidfile="$QGA_PID" >/dev/null 2>&1 &
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
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
    ;;
esac
EOF

# Make the service script executable
chmod +x /userdata/system/services/qemu-ga

batocera-services enable qemu-ga
batocera-services start qemu-ga

dialog --msgbox "QEMU Guest Agent installed and service created!\n\nTo manually control it, use:\n\nbatocera-services {start|stop|restart} qga" 10 60

