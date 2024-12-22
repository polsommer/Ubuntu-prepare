#!/bin/bash

# Pause function
function pause() {
    echo -e "\n\n"
    read -s -n 1 -p "Press any key to continue setup or Ctrl+C to quit..."
    echo -e "\n\n"
}

pause

echo -e '\n\nStarting the Oracle Listener...\n'
# Start the listener (ensure `lsnrctl` is in the PATH or specify its full path).
sudo lsnrctl start

# Create DB
echo -e '\n\nCreating Database in silent mode\n\n\n!!! SAFE TO IGNORE WARNINGS ABOUT PASSWORD !!!\n\nThis step may take some time...\n\n\n'
pause
# Silent mode database creation
sudo dbca -silent -createDatabase -responseFile /opt/oracle/swg-prepare/db_create.rsp
                                                  