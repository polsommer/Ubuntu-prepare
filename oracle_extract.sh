#!/bin/bash

# Pause function
function pause() {
    echo -e "\n\n"
    read -s -n 1 -p "Press any key to continue setup or Ctrl+C to quit..."
    echo -e "\n\n"
}

# Oracle 19c Preinstall Pack
echo -e "\nRunning Oracle Preinstall package\n"
cd ~/ora_dependencies
sudo dpkg -i oracle-database-preinstall-19c_1.0-2_amd64.deb || sudo apt-get install -f -y

# Set Paths in Oracle bashrc
echo -e "\nQueuing PATH setup for Oracle environment\n"
pause
sudo bash ~/swg-prepare/oracle_paths.sh

# Create directories and extract Oracle DB
echo "Creating directories and extracting Oracle Database"
pause
sudo mkdir -p /u01/app/oracle/product/19.3.0/dbhome_1
sudo unzip -d /u01/app/oracle/product/19.3.0/dbhome_1/ ~/ora_dependencies/LINUX.X64_193000_db_home.zip
sudo chown -R oracle:oinstall /u01
sudo chmod -R 775 /u01

# Queue installation scripts for Oracle user
echo -e "\nQueueing installation scripts for transfer to Oracle user\n"
pause
bash ~/swg-prepare/oracle_user.sh
