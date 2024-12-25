#!/bin/bash

# Pause function
function pause() {
    echo -e "\n\n"
    read -s -n 1 -p "Press any key to continue setup or Ctrl+C to quit..."
    echo -e "\n\n"
}

# Queue up Database Installation
echo -e "\nSwitching to Oracle user to queue database installation\n"
sudo -u oracle -H bash -c "bash /home/oracle/Ubuntu-prepare-main/install_oracle_db.sh"

# Run the 1st root script
echo -e "\nRunning the first Oracle root script\n"
pause
sudo bash /u01/app/oraInventory/orainstRoot.sh

# Run the 2nd root script
echo -e "\nRunning the second Oracle root script\n"
pause
sudo bash /u01/app/oracle/product/19.3.0/dbhome_1/root.sh

# Create the database
echo -e "\nProcessing database creation\n"
pause
sudo -u oracle -H bash -c "bash /home/oracle/Ubuntu-prepare-main/create_oracle_db.sh"

# Create `swg` user in the database
echo -e "\nCreating 'swg' user in the database\n"
pause
sudo -u oracle -H bash -c "echo '@/home/oracle/Ubuntu-prepare-main/swgusr.sql' | sqlplus system/swg"
