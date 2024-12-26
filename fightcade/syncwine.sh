#!/bin/bash 

dos2unix /userdata/system/add-ons/fightcade/extra/unwine.sh 2>/dev/null 
chmod a+x /userdata/system/add-ons/fightcade/extra/unwine.sh 2>/dev/null 

# wait for fc2 to load 
sleep 3 

# keep checking if fc2 is running 
while ps axg | grep -vw grep | grep -w fc2-electron > /dev/null; do 
sleep 3 
done 
# if fc2 is closed, unlink wine environment  
/userdata/system/add-ons/fightcade/extra/unwine.sh 
exit 0; exit 1; exit 2; 
