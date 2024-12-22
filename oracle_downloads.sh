#!/bin/bash

# Download Oracle 19.3.0 Database
echo "Downloading Oracle Database Utilities"

# Create dependencies folder if it doesn't exist
mkdir -p ~/ora_dependencies
cd ~/ora_dependencies

# Oracle 19c Preinstall Pack (RPM will be converted for Ubuntu)
echo "Downloading Oracle 19c Preinstall Pack (RPM format)..."
wget https://www.swgevolve.com/oracle_deps/oracle-database-preinstall-19c-1.0-2.el8.x86_64.rpm

# Convert RPM to DEB for Ubuntu
echo "Converting RPM to DEB format for Ubuntu..."
sudo apt update
sudo apt install alien -y
sudo alien -k --scripts oracle-database-preinstall-19c-1.0-2.el8.x86_64.rpm

# Install the DEB package
echo "Installing Oracle Preinstall DEB package..."
sudo dpkg -i oracle-database-preinstall-19c_1.0-2_amd64.deb

# Oracle 19c Database
echo "Downloading Oracle 19c Database (ZIP format)..."
wget https://www.swgevolve.com/oracle_deps/LINUX.X64_193000_db_home.zip

# Inform the user to extract manually or via another script
echo "Download complete. Proceed with extraction of the ZIP file if not done automatically."
