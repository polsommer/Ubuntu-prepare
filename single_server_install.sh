#!/bin/bash

# Pause function
function pause() {
    echo -e "\n\n"
    read -s -n 1 -p "Press any key to continue setup or Ctrl+C to quit..."
    echo -e "\n\n"
}

echo -e "\n####################\nWelcome to the SWG Server Preparation Script for Ubuntu!\n####################\n"
pause

# Initialize server setup
echo "Running Initialization Script"
bash ~/swg-prepare/oinit.sh

# Oracle Database Installation
echo "Running Oracle Installation Scripts"
pause
bash ~/swg-prepare/oracle_installer.sh

# Create Oracle Service
echo "Creating Oracle Service"
pause
bash ~/swg-prepare/oservice.sh

# Prepare dependencies for SWG
echo "Creating folder for SWG dependencies"
mkdir -p ~/swg_dependencies
cd ~/swg_dependencies

# Download and install Oracle utilities
echo "Downloading Oracle Utilities"
pause
bash ~/swg-prepare/server_downloads.sh

# Initialize SWG setup
echo "Running SWG Initialization Script"
pause
bash ~/swg-prepare/swginit.sh

# Source environment profiles
echo "Sourcing environment profiles"
pause
source /etc/profile.d/oracle.sh
source /etc/profile.d/java.sh

# Clone and install SWG
echo "Cloning SWG Source"
pause
git clone https://github.com/SWG-Source/swg-main.git ~/swg-main

echo "Building SWG Server"
pause
cd ~/swg-main
ant swg

# Copy server configuration
echo "Copying server configuration file"
pause
sudo cp ~/swg-prepare/servercommon.cfg ~/swg-main/exe/linux/servercommon.cfg
