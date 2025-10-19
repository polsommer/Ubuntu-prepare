#!/bin/bash

set -euo pipefail

INSTANTCLIENT_MAJOR=21
INSTANTCLIENT_RELEASE=21.18.0.0.0-1
INSTANTCLIENT_HOME=""
INSTANTCLIENT_LIB=""
INSTANTCLIENT_INCLUDE=""
INSTANTCLIENT_BIN=""
INSTANTCLIENT_RPM_DIR=${INSTANTCLIENT_RPM_DIR:-/tmp/oracle-instantclient}
DEFAULT_INSTANTCLIENT_BASE_URL="https://download.oracle.com/otn_software/linux/instantclient/2118000"

detect_default_instantclient_arch() {
    local dpkg_arch=""
    if command -v dpkg >/dev/null 2>&1; then
        dpkg_arch=$(dpkg --print-architecture 2>/dev/null || true)
    fi

    case "$dpkg_arch" in
        amd64|x86_64)
            printf 'x86_64\n'
            ;;
        i386|i686)
            printf 'i386\n'
            ;;
        arm64|aarch64)
            printf 'aarch64\n'
            ;;
        *)
            printf 'x86_64\n'
            ;;
    esac
}

INSTANTCLIENT_ARCH=${INSTANTCLIENT_ARCH:-$(detect_default_instantclient_arch)}
INSTANTCLIENT_BASE_URL=${INSTANTCLIENT_BASE_URL:-$DEFAULT_INSTANTCLIENT_BASE_URL}

INSTANTCLIENT_COMPONENTS=()

if [[ -n "${INSTANTCLIENT_COMPONENTS_OVERRIDE:-}" ]]; then
    mapfile -t INSTANTCLIENT_COMPONENTS <<<"${INSTANTCLIENT_COMPONENTS_OVERRIDE}"
else
    INSTANTCLIENT_COMPONENTS=(
        "oracle-instantclient-basiclite-${INSTANTCLIENT_RELEASE}.${INSTANTCLIENT_ARCH}.rpm|${INSTANTCLIENT_BASE_URL%/}/oracle-instantclient-basiclite-${INSTANTCLIENT_RELEASE}.${INSTANTCLIENT_ARCH}.rpm"
        "oracle-instantclient-devel-${INSTANTCLIENT_RELEASE}.${INSTANTCLIENT_ARCH}.rpm|${INSTANTCLIENT_BASE_URL%/}/oracle-instantclient-devel-${INSTANTCLIENT_RELEASE}.${INSTANTCLIENT_ARCH}.rpm"
        "oracle-instantclient-sqlplus-${INSTANTCLIENT_RELEASE}.${INSTANTCLIENT_ARCH}.rpm|${INSTANTCLIENT_BASE_URL%/}/oracle-instantclient-sqlplus-${INSTANTCLIENT_RELEASE}.${INSTANTCLIENT_ARCH}.rpm"
    )
fi

export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-noninteractive}

ensure_ubuntu_24() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
    fi

    if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *"ubuntu"* ]]; then
        echo "This script can only be executed on Ubuntu." >&2
        exit 1
    fi

    if [[ ${VERSION_ID:-} != 24.* ]]; then
        echo "This script is limited to Ubuntu 24.04 LTS systems." >&2
        exit 1
    fi
}

ensure_required_architecture() {
    if [[ "$INSTANTCLIENT_ARCH" == "i386" ]]; then
        if ! dpkg --print-foreign-architectures | grep -qx 'i386'; then
            dpkg --add-architecture i386
            apt-get update
        fi
    fi
}

refresh_repos() {
    apt-get update
}

install_packages() {
    if (($#)); then
        apt-get install -y --no-install-recommends "$@"
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

download_instantclient_rpms() {
    local rpm_dir=$INSTANTCLIENT_RPM_DIR
    mkdir -p "$rpm_dir"
    pushd "$rpm_dir" >/dev/null

    local entry file url needs_gdown=false

    for entry in "${INSTANTCLIENT_COMPONENTS[@]}"; do
        url=${entry#*|}
        file=${entry%%|*}
        if [[ ! -f "$file" && "$url" == *"drive.google.com"* ]]; then
            needs_gdown=true
            break
        fi
    done

    if [[ "$needs_gdown" == true ]]; then
        ensure_gdown
    fi

    for entry in "${INSTANTCLIENT_COMPONENTS[@]}"; do
        file=${entry%%|*}
        url=${entry#*|}
        if [[ -f "$file" ]]; then
            continue
        fi

        if [[ "$url" == *"drive.google.com"* ]]; then
            gdown --fuzzy --output "$file" "$url"
        else
            wget -O "$file" "$url"
        fi
    done

    popd >/dev/null
}

ensure_gdown() {
    if command -v gdown >/dev/null 2>&1; then
        return
    fi

    install_packages python3 python3-pip

    if ! python3 -m pip show gdown >/dev/null 2>&1; then
        python3 -m pip install --break-system-packages gdown
    fi
}

install_instantclient_rpms() {
    local rpm_dir=$INSTANTCLIENT_RPM_DIR
    local entry file path
    for entry in "${INSTANTCLIENT_COMPONENTS[@]}"; do
        file=${entry%%|*}
        path="$rpm_dir/$file"
        if [[ ! -f "$path" ]]; then
            echo "Expected Oracle Instant Client RPM '$path' was not found." >&2
            exit 1
        fi
        if ! command -v alien >/dev/null 2>&1; then
            echo "The 'alien' utility is required to install Oracle Instant Client RPMs on Ubuntu." >&2
            echo "Install it with: sudo apt-get install -y alien" >&2
            exit 1
        fi
        alien --scripts -i "$path"
    done
}

resolve_instantclient_layout() {
    local home_candidates=(
        "/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client64"
        "/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client32"
        "/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client"
    )
    local include_candidates=(
        "/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client64"
        "/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client32"
        "/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client"
    )

    if [[ "$INSTANTCLIENT_ARCH" == "i386" ]]; then
        home_candidates=(
            "/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client32"
            "/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client"
            "/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client64"
        )
        include_candidates=(
            "/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client32"
            "/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client"
            "/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client64"
        )
    fi

    local candidate
    for candidate in "${home_candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            INSTANTCLIENT_HOME=$candidate
            break
        fi
    done

    if [[ -z "$INSTANTCLIENT_HOME" ]]; then
        INSTANTCLIENT_HOME=${home_candidates[0]}
    fi

    INSTANTCLIENT_LIB="${INSTANTCLIENT_HOME}/lib"
    INSTANTCLIENT_BIN="${INSTANTCLIENT_HOME}/bin"

    if [[ ! -d "$INSTANTCLIENT_HOME" || ! -d "$INSTANTCLIENT_LIB" ]]; then
        echo "Unable to locate the Oracle Instant Client 21 home under /usr/lib/oracle." >&2
        exit 1
    fi

    for candidate in "${include_candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            INSTANTCLIENT_INCLUDE=$candidate
            break
        fi
    done

    if [[ -z "$INSTANTCLIENT_INCLUDE" ]]; then
        INSTANTCLIENT_INCLUDE=${include_candidates[0]}
    fi
}

ensure_ubuntu_24
ensure_required_architecture
refresh_repos

packages=(
    alien
    apache2
    libapache2-mod-php
    build-essential
    gcc
    g++
    libaio1
    libnsl2
    make
    perl
    php
    php-cli
    php-dev
    php-pear
    php-xml
    php-mbstring
    unzip
    wget
    pkg-config
)

if [[ "$INSTANTCLIENT_ARCH" == "i386" ]]; then
    packages+=(
        libaio1:i386
        libnsl2:i386
    )
fi

install_packages "${packages[@]}"

# Download and install the Oracle Instant Client RPMs (basiclite/devel/sqlplus)
download_instantclient_rpms
install_instantclient_rpms
resolve_instantclient_layout

# Install PHP OCI8
printf 'instantclient,%s\n' "${INSTANTCLIENT_LIB}" | pecl install -f oci8

php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
php_cli_ini="/etc/php/${php_version}/cli/php.ini"
php_apache_ini="/etc/php/${php_version}/apache2/php.ini"

if [[ -z "$php_version" || ! -f "$php_cli_ini" || ! -f "$php_apache_ini" ]]; then
    echo "Unable to locate PHP configuration for version '${php_version}'." >&2
    exit 1
fi

# Ensure PHP loads the OCI8 extension
append_unique "extension=oci8.so" "$php_cli_ini"
append_unique "extension=oci8.so" "$php_apache_ini"

# Enable the Apache PHP module and expose Oracle environment variables
a2enmod "php${php_version}"

cat <<EOF >/etc/profile.d/oracle-instantclient.sh
export ORACLE_HOME=${INSTANTCLIENT_HOME}
export LD_LIBRARY_PATH=${INSTANTCLIENT_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export PATH=${INSTANTCLIENT_BIN}:\$PATH
EOF

cat <<EOF >/etc/apache2/conf-available/oci8.conf
SetEnv ORACLE_HOME ${INSTANTCLIENT_HOME}
SetEnv LD_LIBRARY_PATH ${INSTANTCLIENT_LIB}
EOF

a2enconf oci8

ldconfig

# Restart Apache2 to pick up the new configuration and extension
systemctl restart apache2
