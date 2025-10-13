#!/bin/bash

set -euo pipefail

INSTANTCLIENT_VERSION=12.2
INSTANTCLIENT_HOME=/usr/lib/oracle/${INSTANTCLIENT_VERSION}/client
INSTANTCLIENT_LIB=${INSTANTCLIENT_HOME}/lib
INSTANTCLIENT_INCLUDE=/usr/include/oracle/${INSTANTCLIENT_VERSION}/client
INSTANTCLIENT_BIN=${INSTANTCLIENT_HOME}/bin
INSTANTCLIENT_RPM_DIR=${INSTANTCLIENT_RPM_DIR:-/tmp/oracle-instantclient}
GDOWN_ARCHIVE_URL="https://github.com/tekaohswg/gdown.pl/archive/v1.4.zip"
GDOWN_DIR="gdown.pl-1.4"
INSTANTCLIENT_COMPONENTS=(
    "oracle-instantclient12.2-basiclite-12.2.0.1.0-1.i386.rpm|https://drive.google.com/file/d/1q5JuxmYjZTKSFfuh1dWvjnTA107rGuQR"
    "oracle-instantclient12.2-devel-12.2.0.1.0-1.i386.rpm|https://drive.google.com/file/d/1FGO_hpHJ8-lhqvfTppAV1nCBV1bwcQF5"
    "oracle-instantclient12.2-sqlplus-12.2.0.1.0-1.i386.rpm|https://drive.google.com/file/d/1kenKU9WK7gS0OLX1wB3LtonKrPUZT8kH"
)

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

install_optional_packages() {
    local pkg
    for pkg in "$@"; do
        zypper --non-interactive install --no-recommends "$pkg" || \
            echo "Optional package '$pkg' could not be installed; continuing." >&2
    done
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

    if [[ ! -d "$GDOWN_DIR" ]]; then
        wget -O v1.4.zip "$GDOWN_ARCHIVE_URL"
        unzip -o v1.4.zip
        rm -f v1.4.zip
    fi

    local entry file url
    for entry in "${INSTANTCLIENT_COMPONENTS[@]}"; do
        file=${entry%%|*}
        url=${entry#*|}
        if [[ ! -f "$file" ]]; then
            "./$GDOWN_DIR/gdown.pl" "$url" "$file"
        fi
    done

    rm -rf "$GDOWN_DIR"
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

ensure_opensuse_16
refresh_repos

zypper --non-interactive install --type pattern devel_basis

install_packages \
    ant \
    bc \
    bison \
    clang \
    cmake \
    flex \
    gcc \
    gcc-c++ \
    gcc-32bit \
    git \
    java-11-openjdk \
    java-11-openjdk-devel \
    libaio1 \
    libaio1-32bit \
    libnsl1-32bit \
    libcurl4 \
    libcurl4-32bit \
    libgcc_s1-32bit \
    libncurses5 \
    libncurses5-32bit \
    libpcre1 \
    libpcre1-32bit \
    libsqlite3-0 \
    libsqlite3-0-32bit \
    libxml2-2 \
    libxml2-2-32bit \
    linux-glibc-devel \
    perl \
    psmisc \
    python3-ply \
    sqlite3 \
    zlib-devel \
    zlib-devel-32bit

install_optional_packages \
    boost-devel \
    libboost_program_options1_82_0 \
    libboost_program_options1_82_0-32bit

# Acquire and install the Oracle Instant Client components required by SWG tooling
download_instantclient_rpms
install_instantclient_rpms

# set env vars
append_unique "${INSTANTCLIENT_LIB}" /etc/ld.so.conf.d/oracle.conf
append_unique "export ORACLE_HOME=${INSTANTCLIENT_HOME}" /etc/profile.d/oracle.sh
append_unique "export PATH=\$PATH:${INSTANTCLIENT_BIN}" /etc/profile.d/oracle.sh
append_unique "export LD_LIBRARY_PATH=${INSTANTCLIENT_LIB}:${INSTANTCLIENT_INCLUDE}" /etc/profile.d/oracle.sh

if [[ -d "${INSTANTCLIENT_INCLUDE}" && ! -e "${INSTANTCLIENT_HOME}/include" ]]; then
    ln -s "${INSTANTCLIENT_INCLUDE}" "${INSTANTCLIENT_HOME}/include"
fi

ldconfig

JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
if [[ -n "$JAVA_HOME" ]]; then
    append_unique "export JAVA_HOME=$JAVA_HOME" /etc/profile.d/java.sh
fi
