#!/bin/bash

set -euo pipefail

ensure_opensuse_16() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
    fi

    if [[ "${ID:-}" != "opensuse" && "${ID_LIKE:-}" != *"opensuse"* ]]; then
        echo "This script can only be executed on openSUSE." >&2
        exit 1
    fi

    if [[ "${VERSION_ID:-}" != "16" ]]; then
        echo "This script is limited to openSUSE 16 systems." >&2
        exit 1
    fi
}

refresh_repos() {
    zypper --non-interactive refresh
}

install_packages() {
    local missing=()
    local pkg
    for pkg in "$@"; do
        if ! zypper --non-interactive install --no-recommends "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if ((${#missing[@]})); then
        echo "Unable to install required packages: ${missing[*]}" >&2
        exit 1
    fi
}

append_unique() {
    local line=$1
    local file=$2
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if ! grep -Fxq "$line" "$file"; then
        echo "$line" >>"$file"
    fi
}

ensure_opensuse_16
refresh_repos

install_packages \
    alien \
    apache2 \
    apache2-mod_php7 \
    gcc \
    gcc-c++ \
    libaio1 \
    make \
    php7 \
    php7-cli \
    php7-devel \
    php7-pear \
    unzip \
    wget

# Get the instantclients
wget https://github.com/tekaohswg/gdown.pl/archive/v1.4.zip
unzip v1.4.zip
rm v1.4.zip
./gdown.pl-1.4/gdown.pl 'https://drive.google.com/open?id=1PFtRlatlozfairdclfHI-46CwaVGQAb-' 'oracle-instantclient18.5-basic-18.5.0.0.0-3.x86_64.rpm'
./gdown.pl-1.4/gdown.pl 'https://drive.google.com/open?id=15NXyoE2eaOAQoO3c3Ttp87HBR5hWBN4G' 'oracle-instantclient18.5-devel-18.5.0.0.0-3.x86_64.rpm'
rm -r gdown.pl-1.4

# Install the instantclients
alien -i oracle-instantclient18.5-basic-18.5.0.0.0-3.x86_64.rpm
alien -i oracle-instantclient18.5-devel-18.5.0.0.0-3.x86_64.rpm

# Install PHP OCI8
echo "instantclient,/usr/lib/oracle/18.5/client64/lib" | pecl install oci8

# Add some config to PHP and Apache2
append_unique "extension=oci8.so" /etc/php7/cli/php.ini
append_unique "extension=oci8.so" /etc/php7/apache2/php.ini

cat <<'EOF' >/etc/profile.d/oracle-instantclient.sh
export ORACLE_HOME=/usr/lib/oracle/18.5/client64
export LD_LIBRARY_PATH=/usr/lib/oracle/18.5/client64/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
EOF

cat <<'EOF' >/etc/apache2/conf.d/oci8.conf
SetEnv ORACLE_HOME /usr/lib/oracle/18.5/client64
SetEnv LD_LIBRARY_PATH /usr/lib/oracle/18.5/client64/lib
EOF

# Restart Apache2
systemctl restart apache2
