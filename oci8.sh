#!/bin/bash

# Update system and install required dependencies
echo "Updating system and installing dependencies..."
sudo apt-get update
sudo apt-get install -y alien php-dev php-pear libaio1 build-essential wget unzip

# Download gdown.pl script for Google Drive file download
echo "Downloading gdown.pl script..."
wget https://github.com/tekaohswg/gdown.pl/archive/v1.4.zip
unzip v1.4.zip
rm v1.4.zip

# Download Oracle Instant Client RPMs
echo "Downloading Oracle Instant Client RPMs..."
./gdown.pl-1.4/gdown.pl 'https://drive.google.com/open?id=1PFtRlatlozfairdclfHI-46CwaVGQAb-' 'oracle-instantclient18.5-basic-18.5.0.0.0-3.x86_64.rpm'
./gdown.pl-1.4/gdown.pl 'https://drive.google.com/open?id=15NXyoE2eaOAQoO3c3Ttp87HBR5hWBN4G' 'oracle-instantclient18.5-devel-18.5.0.0.0-3.x86_64.rpm'
rm -r gdown.pl-1.4

# Convert and install RPM packages
echo "Converting and installing RPM packages..."
sudo alien -i oracle-instantclient18.5-basic-18.5.0.0.0-3.x86_64.rpm
sudo alien -i oracle-instantclient18.5-devel-18.5.0.0.0-3.x86_64.rpm

# Install PHP OCI8 extension
echo "Installing PHP OCI8 extension..."
echo "instantclient,/usr/lib/oracle/18.5/client64/lib" | sudo pecl install oci8

# Configure PHP and Apache2
echo "Configuring PHP and Apache2..."
sudo bash -c 'echo "extension=oci8.so" >> /etc/php/$(php -r "echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;")/cli/php.ini'
sudo bash -c 'echo "extension=oci8.so" >> /etc/php/$(php -r "echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;")/apache2/php.ini'
sudo bash -c 'echo "export ORACLE_HOME=/usr/lib/oracle/18.5/client64" >> /etc/apache2/envvars'
sudo bash -c 'echo "export LD_LIBRARY_PATH=/usr/lib/oracle/18.5/client64/lib" >> /etc/apache2/envvars'

# Restart Apache2
echo "Restarting Apache2..."
sudo systemctl restart apache2

echo "OCI8 installation and configuration completed successfully!"
