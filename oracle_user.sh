#!/bin/bash

# Move installation scripts to Oracle User directory
echo "Transferring install scripts to Oracle user directory"

# Create the directory if it doesn't exist
sudo mkdir -p /home/oracle/Ubuntu-prepare-main

# Copy required scripts and files
sudo cp ~/Ubuntu-prepare-main/install_oracle_db.sh /home/oracle/Ubuntu-prepare-main
sudo cp ~/Ubuntu-prepare-main/create_oracle_db.sh /home/oracle/Ubuntu-prepare-main
sudo cp ~/Ubuntu-prepare-main/db_create.rsp /home/oracle/Ubuntu-prepare-main
sudo cp ~/Ubuntu-prepare-main/swgusr.sql /home/oracle/Ubuntu-prepare-main

# Set ownership and permissions
sudo chown -R oracle:oinstall /home/oracle/Ubuntu-prepare-main
sudo chmod -R 775 /home/oracle/Ubuntu-prepare-main

echo "Scripts successfully transferred and permissions set."
