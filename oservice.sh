#!/bin/bash

# Copy the Oracle Database service files to systemd directory
echo "Copying Oracle Database service files to /etc/systemd/system/"
sudo mkdir -p /etc/systemd/system
sudo cp ~/Ubuntu-prepare-main/includes/odb/odb.service /etc/systemd/system/

# Copy start and stop scripts for Oracle Database
echo "Copying Oracle start/stop scripts to /etc/"
sudo cp ~/Ubuntu-prepare-main/includes/odb/odb-start.sh /etc/
sudo cp ~/Ubuntu-prepare-main/includes/odb/odb-stop.sh /etc/

# Set executable permissions for start/stop scripts
echo "Setting executable permissions for start/stop scripts"
sudo chmod +x /etc/odb-start.sh
sudo chmod +x /etc/odb-stop.sh

# Enable and reload the Oracle Database service
echo "Enabling and reloading the Oracle Database service"
sudo systemctl daemon-reload
sudo systemctl enable odb.service

echo "Oracle Database service setup completed successfully."
