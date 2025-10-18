#!/bin/bash

set -euo pipefail

INSTANTCLIENT_MAJOR=21
INSTANTCLIENT_RELEASE=21.18.0.0.0-1
INSTANTCLIENT_HOME=""
INSTANTCLIENT_LIB=""
INSTANTCLIENT_INCLUDE=""
INSTANTCLIENT_BIN=""
INSTANTCLIENT_RPM_DIR=${INSTANTCLIENT_RPM_DIR:-/tmp/oracle-instantclient}
INSTANTCLIENT_COMPONENTS=(
    "oracle-instantclient-basiclite-${INSTANTCLIENT_RELEASE}.i386.rpm|https://drive.google.com/file/d/1q5JuxmYjZTKSFfuh1dWvjnTA107rGuQR"
    "oracle-instantclient-devel-${INSTANTCLIENT_RELEASE}.i386.rpm|https://drive.google.com/file/d/1FGO_hpHJ8-lhqvfTppAV1nCBV1bwcQF5"
    "oracle-instantclient-sqlplus-${INSTANTCLIENT_RELEASE}.i386.rpm|https://drive.google.com/file/d/1kenKU9WK7gS0OLX1wB3LtonKrPUZT8kH"
)

if [[ -n "${INSTANTCLIENT_COMPONENTS_OVERRIDE:-}" ]]; then
    mapfile -t INSTANTCLIENT_COMPONENTS <<<"${INSTANTCLIENT_COMPONENTS_OVERRIDE}"
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

ensure_i386_architecture() {
    if ! dpkg --print-foreign-architectures | grep -qx 'i386'; then
        dpkg --add-architecture i386
        apt-get update
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
        "/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client32"
        "/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client"
    )
    local include_candidates=(
        "/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client32"
        "/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client"
    )

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
ensure_i386_architecture
refresh_repos

install_packages \
    alien \
    apache2 \
    libapache2-mod-php \
    build-essential \
    gcc \
    g++ \
    libaio1 \
    libaio1:i386 \
    libnsl2 \
    libnsl2:i386 \
    make \
    perl \
    php \
    php-cli \
    php-dev \
    php-pear \
    php-xml \
    php-mbstring \
    unzip \
    wget \
    pkg-config

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
