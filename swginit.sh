#!/bin/bash

# Pause function
function pause() {
    echo -e "\n\n"
    read -s -n 1 -p "Press any key to continue setup or Ctrl+C to quit..."
    echo -e "\n\n"
}

pause

# Install SWG Dependencies
echo -e "\nInstalling Dependencies for Compiling SWG"
sudo apt update
sudo apt install -y ant clang bison flex cmake libaio-dev gcc-multilib g++-multilib libncurses5-dev libxml2-dev libpcre3-dev libcurl4-openssl-dev libboost-all-dev sqlite3 libsqlite3-dev

# Install Boost
echo -e "\nDownloading and Installing Boost Libraries"
cd ~/swg_dependencies
wget https://boostorg.jfrog.io/artifactory/main/release/1.85.0/source/boost_1_85_0.zip
unzip boost_1_85_0.zip
cd boost_1_85_0
./bootstrap.sh
sudo ./b2 install

# Install Oracle Instant Clients
echo -e "\nInstalling Oracle Instant Clients"
pause
cd ~/swg_dependencies
sudo alien -i ~/swg_dependencies/oracle-instantclient18.3-basic-18.3.0.0.0-1.i386.rpm
sudo alien -i ~/swg_dependencies/oracle-instantclient18.3-devel-18.3.0.0.0-1.i386.rpm
sudo alien -i ~/swg_dependencies/oracle-instantclient18.3-sqlplus-18.3.0.0.0-1.i386.rpm

pause

# Set Environment Variables
echo -e "\nSetting Environment Variables"
sudo tee /etc/ld.so.conf.d/oracle.conf > /dev/null <<EOF
/usr/lib/oracle/18.3/client/lib
EOF

sudo tee /etc/profile.d/oracle.sh > /dev/null <<EOF
export ORACLE_HOME=/usr/lib/oracle/18.3/client
export PATH=\$PATH:/usr/lib/oracle/18.3/client/bin
export LD_LIBRARY_PATH=/usr/lib/oracle/18.3/client/lib:/usr/include/oracle/18.3/client
EOF

sudo ldconfig

sudo tee /etc/profile.d/java.sh > /dev/null <<EOF
export JAVA_HOME=/usr/lib/jvm/zulu-17-x86
EOF

echo "SWG Initialization Complete."
