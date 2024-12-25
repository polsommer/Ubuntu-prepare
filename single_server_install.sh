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
bash ~/Ubuntu-prepare-main/oinit.sh

# Oracle Database Installation
echo "Running Oracle Installation Scripts"
pause
bash ~/Ubuntu-prepare-main/oracle_installer.sh

# Create Oracle Service
echo "Creating Oracle Service"
pause
bash ~/Ubuntu-prepare-main/oservice.sh

# Prepare dependencies for SWG
echo "Creating folder for SWG dependencies"
mkdir -p ~/swg_dependencies
cd ~/swg_dependencies

# Download and install Oracle utilities
echo "Downloading Oracle Utilities"
pause
bash ~/Ubuntu-prepare-main/server_downloads.sh

# Initialize SWG setup
echo "Running SWG Initialization Script"
pause
bash ~/Ubuntu-prepare-main/swginit.sh

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
sudo cp ~/Ubuntu-prepare-main/servercommon.cfg ~/swg-main/exe/linux/servercommon.cfg
