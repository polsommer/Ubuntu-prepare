#!/bin/bash

set -e

echo -e "\n💡 Installing 32-bit Azul Zulu JDK 17 on openSUSE...\n"

# Define installation variables
JDK_VERSION="zulu17.58.21-ca-jdk17.0.15-linux_i686"
JDK_TAR="$JDK_VERSION.tar.gz"
JDK_URL="https://cdn.azul.com/zulu/bin/$JDK_TAR"
INSTALL_DIR="/usr/lib/jvm"
TARGET_DIR="$INSTALL_DIR/$JDK_VERSION"
SYMLINK_PATH="$INSTALL_DIR/zulu-17-x86"

# Pause function
function pause() {
    echo -e "\n"
    read -s -n 1 -p "Press any key to continue or Ctrl+C to cancel..."
    echo -e "\n"
}

# Ensure dependencies
echo "🔧 Installing required tools..."
sudo zypper install -y wget tar

# Create installation directory
echo "📂 Preparing JVM directory..."
sudo mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download JDK if not already downloaded
if [ ! -f "$JDK_TAR" ]; then
    echo "⬇️  Downloading Zulu JDK..."
    wget "$JDK_URL"
else
    echo "✅ JDK archive already exists."
fi

# Extract and install
if [ ! -d "$TARGET_DIR" ]; then
    echo "📦 Extracting JDK..."
    sudo tar -xvzf "$JDK_TAR"
else
    echo "✅ JDK directory already extracted."
fi

# Create or refresh symlink
if [ -L "$SYMLINK_PATH" ]; then
    sudo rm "$SYMLINK_PATH"
fi
sudo ln -s "$TARGET_DIR" "$SYMLINK_PATH"

# Set environment variables
echo "🔧 Setting JAVA_HOME and LD_LIBRARY_PATH..."
sudo tee /etc/profile.d/java.sh > /dev/null <<EOF
export JAVA_HOME=$SYMLINK_PATH
export PATH=\$JAVA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$JAVA_HOME/lib:\$JAVA_HOME/lib/server:\$LD_LIBRARY_PATH
EOF

# Refresh dynamic linker path
echo "$SYMLINK_PATH/lib/server" | sudo tee /etc/ld.so.conf.d/zulu-17.conf
sudo ldconfig

# Apply changes now
source /etc/profile.d/java.sh

# Final verification
echo -e "\n✅ Installation complete! Verifying setup...\n"
java -version
file \$JAVA_HOME/lib/server/libjvm.so

echo -e "\n🎉 Zulu 32-bit Java 17 is installed and ready!"
