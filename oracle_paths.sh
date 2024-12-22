#!/bin/bash

# Set Paths in Oracle user's .bashrc
echo "Setting up Oracle environment variables in /home/oracle/.bashrc"

# Append Oracle-specific settings to .bashrc
sudo tee -a /home/oracle/.bashrc > /dev/null <<EOF
# Oracle Settings
export TMP=/tmp
export TMPDIR=\$TMP
export ORACLE_HOSTNAME=swg
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=\$ORACLE_BASE/product/19.3.0/dbhome_1
export ORA_INVENTORY=/u01/app/oraInventory
export ORACLE_SID=swg
export ORACLE_UNQNAME=\$ORACLE_SID
export PATH=/usr/sbin:\$ORACLE_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
export CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
EOF

echo "Oracle environment variables have been set."
