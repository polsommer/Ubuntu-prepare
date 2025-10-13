#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=includes/instantclient.sh
source "$SCRIPT_DIR/includes/instantclient.sh"

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
    apache2 \
    apache2-mod_php7 \
    gcc \
    gcc-c++ \
    libaio1 \
    libaio1-32bit \
    libnsl1-32bit \
    make \
    php7 \
    php7-cli \
    php7-devel \
    php7-pear \
    unzip \
    wget

# Install the Oracle Instant Client RPMs (basiclite/devel/sqlplus)
install_instantclient_rpms

# Install PHP OCI8
echo "instantclient,${INSTANTCLIENT_LIB}" | pecl install oci8

# Add some config to PHP and Apache2
append_unique "extension=oci8.so" /etc/php7/cli/php.ini
append_unique "extension=oci8.so" /etc/php7/apache2/php.ini

cat <<EOF >/etc/profile.d/oracle-instantclient.sh
export ORACLE_HOME=${INSTANTCLIENT_HOME}
export LD_LIBRARY_PATH=${INSTANTCLIENT_LIB}\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
EOF

cat <<EOF >/etc/apache2/conf.d/oci8.conf
SetEnv ORACLE_HOME ${INSTANTCLIENT_HOME}
SetEnv LD_LIBRARY_PATH ${INSTANTCLIENT_LIB}
EOF

# Restart Apache2
systemctl restart apache2
