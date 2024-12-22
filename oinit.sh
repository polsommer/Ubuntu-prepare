#!/bin/bash

# Pause function
function pause() {
    echo -e "\n\n"
    read -s -n 1 -p "Press any key to continue setup or Ctrl+C to quit..."
    echo -e "\n\n"
}

# Check for available updates
echo -e "\nInitializing Server and Checking for updates\n"
pause
sudo apt update && sudo apt upgrade -y

# Make a folder for dependencies
echo -e "\nCreating a folder for dependencies\n"
pause
mkdir -p ~/ora_dependencies
cd ~/ora_dependencies

# Set SELinux to Permissive (SELinux is typically not enforced on Ubuntu, but we'll include equivalent commands)
echo -e "\nDisabling UFW (Firewall)\n"
pause
sudo ufw disable

# Download and install Java (Updated for Ubuntu using Azul OpenJDK)
echo -e "\nDownloading and installing Azul OpenJDK 17\n"
pause
wget https://cdn.azul.com/zulu/bin/zulu17.50.19-ca-jdk17.0.11-linux_amd64.deb
sudo apt install ./zulu17.50.19-ca-jdk17.0.11-linux_amd64.deb -y

# Install additional dependencies for 32-bit compatibility
echo -e "\nInstalling additional dependencies for 32-bit compatibility\n"
pause
sudo apt install libxext6:i386 libxrender1:i386 libxtst6:i386 -y

# Install Python and Pip
echo -e "\nInstalling Python and Pip\n"
pause
sudo apt install python3.9 python3.9-distutils python3.9-venv python3-pip -y

# Download Oracle 19.3.0 Database and Preinstall Pack
echo -e "\nQueueing Oracle Database for download\n"
pause
bash ~/swg-prepare/oracle_downloads.sh

# Make directories and extract Oracle DB
echo -e "\nQueueing Oracle DB Extraction\n"
pause
bash ~/swg-prepare/oracle_extract.sh

# Set Oracle user password
echo -e "\nSetting password for Oracle user\n"
pause
echo "oracle:swg" | sudo chpasswd

echo -e "\nInitialization and setup completed successfully!"

