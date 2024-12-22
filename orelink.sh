#!/bin/bash

# Navigate to Oracle's stub libraries directory
echo "Navigating to Oracle stub libraries directory..."
cd /u01/app/oracle/product/19.3.0/dbhome_1/lib/stubs || {
    echo "Failed to navigate to /u01/app/oracle/product/19.3.0/dbhome_1/lib/stubs"
    exit 1
}

# Remove any libc.* files to avoid conflicts
echo "Removing stub libc files..."
sudo rm -f libc.*

# Navigate to Oracle's binary directory
echo "Navigating to Oracle binary directory..."
cd /u01/app/oracle/product/19.3.0/dbhome_1/bin || {
    echo "Failed to navigate to /u01/app/oracle/product/19.3.0/dbhome_1/bin"
    exit 1
}

# Relink all binaries
echo "Relinking all binaries..."
sudo ./relink all || {
    echo "Relinking failed. Please check the Oracle environment and logs."
    exit 1
}

echo "Relinking completed successfully."
