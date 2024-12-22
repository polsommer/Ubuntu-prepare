#!/bin/bash

# Download Utilities for interacting with the Oracle Database
echo "Downloading Oracle Database Utilities"

# Download Instant Client files
wget https://www.swgevolve.com/oracle_deps/oracle-instantclient18.3-basic-18.3.0.0.0-1.i386.rpm
wget https://www.swgevolve.com/oracle_deps/oracle-instantclient18.3-devel-18.3.0.0.0-1.i386.rpm
wget https://www.swgevolve.com/oracle_deps/oracle-instantclient18.3-sqlplus-18.3.0.0.0-1.i386.rpm

# Convert RPM to DEB
echo "Converting RPM packages to DEB format..."
sudo apt install alien -y
sudo alien -k oracle-instantclient18.3-*.rpm
