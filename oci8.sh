#!/bin/bash

set -euo pipefail

INSTANTCLIENT_MAJOR=21
INSTANTCLIENT_RELEASE=21.18.0.0.0-1
INSTANTCLIENT_HOME=""
INSTANTCLIENT_LIB=""
INSTANTCLIENT_INCLUDE=""
INSTANTCLIENT_BIN=""
INSTANTCLIENT_RPM_DIR=${INSTANTCLIENT_RPM_DIR:-/tmp/oracle-instantclient}
GDOWN_ARCHIVE_URL="https://github.com/tekaohswg/gdown.pl/archive/v1.4.zip"
GDOWN_DIR="gdown.pl-1.4"
INSTANTCLIENT_COMPONENTS=(
    "oracle-instantclient-basiclite-${INSTANTCLIENT_RELEASE}.i386.rpm|https://drive.google.com/file/d/1q5JuxmYjZTKSFfuh1dWvjnTA107rGuQR"
    "oracle-instantclient-devel-${INSTANTCLIENT_RELEASE}.i386.rpm|https://drive.google.com/file/d/1FGO_hpHJ8-lhqvfTppAV1nCBV1bwcQF5"
    "oracle-instantclient-sqlplus-${INSTANTCLIENT_RELEASE}.i386.rpm|https://drive.google.com/file/d/1kenKU9WK7gS0OLX1wB3LtonKrPUZT8kH"
)

if [[ -n "${INSTANTCLIENT_COMPONENTS_OVERRIDE:-}" ]]; then
    mapfile -t INSTANTCLIENT_COMPONENTS <<<"${INSTANTCLIENT_COMPONENTS_OVERRIDE}"
fi

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

    if [[ "$needs_gdown" == true && ! -d "$GDOWN_DIR" ]]; then
        wget -O v1.4.zip "$GDOWN_ARCHIVE_URL"
        unzip -o v1.4.zip
        rm -f v1.4.zip
    fi

    for entry in "${INSTANTCLIENT_COMPONENTS[@]}"; do
        file=${entry%%|*}
        url=${entry#*|}
        if [[ -f "$file" ]]; then
            continue
        fi

        if [[ "$url" == *"drive.google.com"* ]]; then
            "./$GDOWN_DIR/gdown.pl" "$url" "$file"
        else
            wget -O "$file" "$url"
        fi
    done

    if [[ -d "$GDOWN_DIR" ]]; then
        rm -rf "$GDOWN_DIR"
    fi

    popd >/dev/null
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
        zypper --non-interactive install --allow-unsigned-rpm "$path"
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
    perl \
    php7 \
    php7-cli \
    php7-devel \
    php7-pear \
    unzip \
    wget

# Download and install the Oracle Instant Client RPMs (basiclite/devel/sqlplus)
download_instantclient_rpms
install_instantclient_rpms
resolve_instantclient_layout

# Install PHP OCI8
echo "instantclient,${INSTANTCLIENT_LIB}" | pecl install oci8

# Add some config to PHP and Apache2
append_unique "extension=oci8.so" /etc/php7/cli/php.ini
append_unique "extension=oci8.so" /etc/php7/apache2/php.ini

cat <<EOF >/etc/profile.d/oracle-instantclient.sh
export ORACLE_HOME=${INSTANTCLIENT_HOME}
export LD_LIBRARY_PATH=${INSTANTCLIENT_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
EOF

cat <<EOF >/etc/apache2/conf.d/oci8.conf
SetEnv ORACLE_HOME ${INSTANTCLIENT_HOME}
SetEnv LD_LIBRARY_PATH ${INSTANTCLIENT_LIB}
EOF

ldconfig

# Restart Apache2
systemctl restart apache2
