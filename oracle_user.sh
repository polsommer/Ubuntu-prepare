#!/bin/bash

# Move installation scripts to Oracle User directory
echo "Transferring install scripts to Oracle user directory"

# Create the directory if it doesn't exist
sudo mkdir -p /home/oracle/swg-prepare

# Copy required scripts and files
sudo cp ~/swg-prepare/install_oracle_db.sh /home/oracle/swg-prepare
sudo cp ~/swg-prepare/create_oracle_db.sh /home/oracle/swg-prepare
sudo cp ~/swg-prepare/db_create.rsp /home/oracle/swg-prepare
sudo cp ~/swg-prepare/swgusr.sql /home/oracle/swg-prepare

# Set ownership and permissions
sudo chown -R oracle:oinstall /home/oracle/swg-prepare
sudo chmod -R 775 /home/oracle/swg-prepare

echo "Scripts successfully transferred and permissions set."
