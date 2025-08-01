#!/bin/bash

# Make system writable
mount -o remount,rw /

# === Step 1: Set up Java ===
echo "Installing Java..."

mkdir -p /userdata/system/java
cd /userdata/system/java

# Clean up previous download
rm -f microsoft-jdk-17-linux-x64.tar.gz
curl -L -O https://aka.ms/download-jdk/microsoft-jdk-17-linux-x64.tar.gz

# Extract
tar -xzf microsoft-jdk-17-linux-x64.tar.gz
JDK_DIR=$(find . -maxdepth 1 -type d -name "jdk-17*" | head -n 1)
JDK_PATH="/userdata/system/java/$JDK_DIR"

# === Step 2: Set up JDownloader ===
echo "Installing JDownloader..."

mkdir -p /userdata/system/jdownloader
cd /userdata/system/jdownloader

# Download the installer
curl -O http://installer.jdownloader.org/JDownloader2Setup_unix_nojre.sh
chmod +x JDownloader2Setup_unix_nojre.sh

# Run the installer with correct Java path
INSTALL4J_JAVA_HOME="$JDK_PATH" ./JDownloader2Setup_unix_nojre.sh

# === Step 3: Create a launcher script ===
cat <<EOF > /userdata/system/jdownloader/jdownloader2
#!/bin/bash
export INSTALL4J_JAVA_HOME=$JDK_PATH
export PATH=$JDK_PATH/bin:\$PATH
cd /userdata/system/jdownloader/JDownloader2
./JDownloader2
EOF

chmod +x /userdata/system/jdownloader/jdownloader2

# === Step 4: Make settings persistent via custom.sh ===
echo "Setting up startup script..."

CUSTOM_SH="/userdata/system/custom.sh"
mkdir -p /userdata/system

touch "$CUSTOM_SH"

# Remove old entries if present
sed -i '/INSTALL4J_JAVA_HOME/d' "$CUSTOM_SH"
sed -i '/jdownloader2/d' "$CUSTOM_SH"

# Add new entries
cat <<EOF >> "$CUSTOM_SH"
export INSTALL4J_JAVA_HOME=$JDK_PATH
export PATH=$JDK_PATH/bin:\$PATH
nohup /userdata/system/jdownloader/jdownloader2 > /dev/null 2>&1 &
EOF

chmod +x "$CUSTOM_SH"

echo "✅ Done! Reboot Batocera and JDownloader will start automatically."
