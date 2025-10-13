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
    alien \
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
alien -i --target=amd64 ~/oracle-instantclient12.2-basiclite-12.2.0.1.0-1.i386.rpm
alien -i --target=amd64 ~/oracle-instantclient12.2-devel-12.2.0.1.0-1.i386.rpm
alien -i --target=amd64 ~/oracle-instantclient12.2-sqlplus-12.2.0.1.0-1.i386.rpm

# set env vars
append_unique "/usr/lib/oracle/12.2/client/lib" /etc/ld.so.conf.d/oracle.conf
append_unique "export ORACLE_HOME=/usr/lib/oracle/12.2/client" /etc/profile.d/oracle.sh
append_unique "export PATH=\$PATH:/usr/lib/oracle/12.2/client/bin" /etc/profile.d/oracle.sh
append_unique "export LD_LIBRARY_PATH=/usr/lib/oracle/12.2/client/lib:/usr/include/oracle/12.2/client" /etc/profile.d/oracle.sh

ORACLE_HOME=/usr/lib/oracle/12.2/client
if [[ -d /usr/include/oracle/12.2/client && ! -e "$ORACLE_HOME/include" ]]; then
    ln -s /usr/include/oracle/12.2/client "$ORACLE_HOME/include"
fi

ldconfig

JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
if [[ -n "$JAVA_HOME" ]]; then
    append_unique "export JAVA_HOME=$JAVA_HOME" /etc/profile.d/java.sh
fi
