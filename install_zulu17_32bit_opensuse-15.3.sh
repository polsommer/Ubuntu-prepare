#!/bin/bash
set -euo pipefail

# -------------------------------------------------------------------
# Azul Zulu 17 (32-bit) Installer for openSUSE Leap 15.3
# -------------------------------------------------------------------
# This script:
#   • Downloads the latest verified Zulu 17 32-bit JDK from Azul CDN
#   • Extracts it to /usr/lib/jvm/zulu-17-x86
#   • Configures system environment (/etc/profile.d/zulu32.sh)
# -------------------------------------------------------------------

ZULU_URL="https://cdn.azul.com/zulu/bin/zulu17.52.17-ca-jdk17.0.12-linux_i686.tar.gz"
ZULU_TARBALL=$(basename "$ZULU_URL")
ZULU_DIR_NAME="zulu17.52.17-ca-jdk17.0.12-linux_i686"
INSTALL_PATH="/usr/lib/jvm"
TARGET_DIR="${INSTALL_PATH}/zulu-17-x86"
PROFILE_SCRIPT="/etc/profile.d/zulu32.sh"

echo "💡 Installing Azul Zulu OpenJDK 17 (32-bit) on openSUSE Leap 15.3..."

# --- Ensure required tools ---
echo "📦 Installing prerequisites..."
sudo zypper --non-interactive install wget tar gzip > /dev/null

# --- Download Zulu ---
echo "⬇️  Downloading ${ZULU_TARBALL}..."
cd /tmp
if [[ -f "$ZULU_TARBALL" ]]; then
    echo "   Found cached tarball, skipping download."
else
    wget -q "$ZULU_URL" -O "$ZULU_TARBALL"
fi

# --- Extract and install ---
echo "📂 Extracting to ${INSTALL_PATH}..."
sudo mkdir -p "$INSTALL_PATH"
sudo tar -xzf "$ZULU_TARBALL" -C "$INSTALL_PATH"
sudo rm -rf "$TARGET_DIR"
sudo mv "${INSTALL_PATH}/${ZULU_DIR_NAME}" "$TARGET_DIR"

# --- Configure environment ---
echo "⚙️  Creating environment script at ${PROFILE_SCRIPT}..."
sudo tee "$PROFILE_SCRIPT" >/dev/null <<EOF
# --- VM 3.0.2 32-Bit Java ---
# Default to 32-bit Azul Zulu Java 17
export JAVA_HOME=${TARGET_DIR}
export PATH=\$JAVA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$JAVA_HOME/lib:\$JAVA_HOME/lib/server:\$LD_LIBRARY_PATH
EOF

sudo chmod +x "$PROFILE_SCRIPT"

# --- Apply environment for current session ---
echo "🔁 Applying environment..."
source "$PROFILE_SCRIPT"

# --- Verify installation ---
echo "✅ Verifying Java installation..."
java -version || {
    echo "❌ Java verification failed. Check LD_LIBRARY_PATH or paths." >&2
    exit 1
}

echo
echo "🎉 Azul Zulu 17 (32-bit) successfully installed!"
echo "JAVA_HOME=${TARGET_DIR}"
echo "Profile script created: ${PROFILE_SCRIPT}"
echo "You may need to re-login or run:  source ${PROFILE_SCRIPT}"
