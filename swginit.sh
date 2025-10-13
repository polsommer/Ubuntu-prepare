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
    psmisc \
    python3-ply \
    sqlite3 \
    zlib-devel \
    zlib-devel-32bit

install_optional_packages \
    boost-devel \
    libboost_program_options1_82_0 \
    libboost_program_options1_82_0-32bit

# install oracle instantclients
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
