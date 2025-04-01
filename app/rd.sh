#!/bin/bash
clear
echo "This bit.ly link will stop working soon. The new install command will be;"
echo ""
echo "curl -L install.batoaddons.app | bash"
sleep 5
echo ""
echo "Now redirecting to continue instalation..."
sleep 2
clear
curl -fsSL install.batoaddons.app | bash
