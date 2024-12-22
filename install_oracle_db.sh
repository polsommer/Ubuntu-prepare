#!/bin/bash

# Pause function
function pause() {
    echo -e "\n\n"
    read -s -n 1 -p "Press any key to continue setup or Ctrl+C to quit..."
    echo -e "\n\n"
}

pause

echo -e "\nStarting Oracle Database Installation on Ubuntu. This may take some time.\n\n"
echo -e "!!! SAFE TO IGNORE WARNINGS, JUST LET IT RUN !!!\n\n"

# Ensure dependencies are installed
echo -e "Checking and installing required dependencies...\n"
sudo apt update
sudo apt install -y alien libaio1 unixodbc libx11-dev libxrender1 libxtst6

# Directory setup
echo -e "Setting up Oracle directories...\n"
sudo mkdir -p /opt/oracle/product/19.3.0/dbhome_1
sudo chown -R $(whoami):oinstall /opt/oracle
sudo chmod -R 775 /opt/oracle

# Change directory to Oracle installer
cd /opt/oracle/product/19.3.0/dbhome_1

# Set environment variables
echo -e "Configuring environment variables...\n"
export CV_ASSUME_DISTID=OEL8.10
export ORACLE_HOME=/opt/oracle/product/19.3.0/dbhome_1
export ORACLE_BASE=/opt/oracle
export ORA_INVENTORY=/opt/oracle/oraInventory
export ORACLE_HOSTNAME=$(hostname)

# Run Oracle installer
echo -e "Starting the Oracle installer...\n"
sudo ./runInstaller -ignorePrereq -waitforcompletion -silent                        \
    -responseFile ${ORACLE_HOME}/install/response/db_install.rsp               \
    oracle.install.option=INSTALL_DB_SWONLY                                    \
    ORACLE_HOSTNAME=${ORACLE_HOSTNAME}                                         \
    UNIX_GROUP_NAME=oinstall                                                   \
    INVENTORY_LOCATION=${ORA_INVENTORY}                                        \
    SELECTED_LANGUAGES=en,en_GB                                                \
    ORACLE_HOME=${ORACLE_HOME}                                                 \
    ORACLE_BASE=${ORACLE_BASE}                                                 \
    oracle.install.db.InstallEdition=EE                                        \
    oracle.install.db.OSDBA_GROUP=dba                                          \
    oracle.install.db.OSBACKUPDBA_GROUP=dba                                    \
    oracle.install.db.OSDGDBA_GROUP=dba                                        \
    oracle.install.db.OSKMDBA_GROUP=dba                                        \
    oracle.install.db.OSRACDBA_GROUP=dba                                       \
    SECURITY_UPDATES_VIA_MYORACLESUPPORT=false                                 \
    DECLINE_SECURITY_UPDATES=true

echo -e "\nOracle Database Installation Completed.\n"
pause
