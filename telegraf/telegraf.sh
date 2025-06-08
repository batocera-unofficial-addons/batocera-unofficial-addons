#!/bin/bash
export $(cat /proc/1/environ | tr '\0' '\n')

# Step 1: Install Telegraf
echo "Installing Telegraf..."
mkdir -p /userdata/temp
cd /userdata/temp || exit 1

# https://github.com/influxdata/telegraf/releases
FILEBase=${FILEBase:-"telegraf-"}
FILEVersion=${FILEVerion:-"1.34.4"}

ARCH=$(uname -m)

case "$ARCH" in
  x86_64)
    FILE="${FILEBase}${FILEVersion}_linux_amd64.tar.gz"
    ;;
  armv7l)
    FILE="${FILEBase}${FILEVersion}_linux_armhf.tar.gz"
    ;;
  aarch64)
    FILE="${FILEBase}${FILEVersion}_linux_arm64.tar.gz"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Detected architecture: $ARCH"
echo "Downloading $FILE..."
wget -q "https://dl.influxdata.com/telegraf/releases/${FILE}"

echo "Extracting..."
tar -xf "$FILE"
DIR="${FILEBase}${FILEVersion}"
cd "$DIR" || exit 1

mkdir -p /userdata/add-ons/telegraf/etc/telegraf/telegraf.d
mkdir -p /userdata/add-ons/telegraf/log

mv usr/lib/telegraf/scripts/telegraf.service /userdata/add-ons/telegraf
mv usr/bin/telegraf /userdata/add-ons/telegraf/telegraf
if [ ! -f /userdata/add-ons/telegraf/telegraf.conf ]; then
  mv etc/telegraf/telegraf.conf /userdata/add-ons/telegraf/etc/telegraf
fi

if [ ! -f /userdata/add-ons/telegraf/telegraf.conf.default ]; then
  cp /userdata/add-ons/telegraf/etc/telegraf/telegraf.conf /userdata/add-ons/telegraf/etc/telegraf/telegraf.conf.default
fi

# Cleanup temporary files
cd /userdata || exit 1
rm -rf /userdata/temp

# Configure Telegraf as a service
echo "Configuring Telegraf service..."
mkdir -p /userdata/system/services
cat << 'EOF' > /userdata/system/services/telegraf
#!/bin/bash

if [[ "$1" != "start" ]]; then
  exit 0
fi

# Start Telegraf daemon
/userdata/add-ons/telegraf/telegraf \
  --config /userdata/add-ons/telegraf/etc/telegraf/telegraf.conf \
  --config-directory /userdata/add-ons/telegraf/etc/telegraf/telegraf.d \
    > /userdata/add-ons/telegraf/log/telegraf.log 2>&1 &
EOF

chmod +x /userdata/system/services/telegraf

# Enable and start the Telegraf service
batocera-services enable telegraf
batocera-services start telegraf
