#!/bin/bash

set -euo pipefail

INSTANTCLIENT_MAJOR=${INSTANTCLIENT_MAJOR:-21}
INSTANTCLIENT_RELEASE=${INSTANTCLIENT_RELEASE:-21.18.0.0.0-1}

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

if [[ -z "${ORACLE_INSTANTCLIENT_BASE_URL:-}" ]]; then
    ORACLE_INSTANTCLIENT_BASE_URL="https://download.oracle.com/otn_software/linux/instantclient/2118000"
fi

if [[ -z "${INSTANTCLIENT_HOME:-}" ]]; then
    if [[ "$INSTANTCLIENT_ARCH" == "i386" ]]; then
        INSTANTCLIENT_HOME="/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client32"
    else
        INSTANTCLIENT_HOME="/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client64"
    fi
fi

INSTANTCLIENT_LIB=${INSTANTCLIENT_LIB:-${INSTANTCLIENT_HOME}/lib}
INSTANTCLIENT_BIN=${INSTANTCLIENT_BIN:-${INSTANTCLIENT_HOME}/bin}

if [[ -z "${INSTANTCLIENT_INCLUDE:-}" ]]; then
    if [[ "$INSTANTCLIENT_ARCH" == "i386" ]]; then
        INSTANTCLIENT_INCLUDE="/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client32"
    else
        INSTANTCLIENT_INCLUDE="/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client64"
    fi
fi

# Packages are expected to match the naming convention distributed by Oracle
# (for example oracle-instantclient-basiclite-21.18.0.0.0-1.i386.rpm).
INSTANTCLIENT_PACKAGES=(
    "oracle-instantclient-basiclite-${INSTANTCLIENT_RELEASE}.${INSTANTCLIENT_ARCH}.rpm"
    "oracle-instantclient-devel-${INSTANTCLIENT_RELEASE}.${INSTANTCLIENT_ARCH}.rpm"
    "oracle-instantclient-sqlplus-${INSTANTCLIENT_RELEASE}.${INSTANTCLIENT_ARCH}.rpm"
)

ensure_download_tool() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOAD_TOOL="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOAD_TOOL="wget"
    else
        echo "Either curl or wget is required to download Oracle Instant Client packages." >&2
        exit 1
    fi
}

fetch_package() {
    local url=$1
    local destination=$2
    case ${DOWNLOAD_TOOL:-} in
        curl)
            curl -fL --retry 3 --output "$destination" "$url"
            ;;
        wget)
            wget -q -O "$destination" "$url"
            ;;
        *)
            echo "No download tool configured." >&2
            exit 1
            ;;
    esac
}

resolve_instantclient_rpm_dir() {
    local rpm_dir=${ORACLE_INSTANTCLIENT_RPM_DIR:-}
    local default_base=${SCRIPT_DIR:-$(pwd)}
    local package

    if [[ -n "$rpm_dir" ]]; then
        if [[ ! -d "$rpm_dir" ]]; then
            echo "Provided ORACLE_INSTANTCLIENT_RPM_DIR '$rpm_dir' does not exist." >&2
            exit 1
        fi
    else
        rpm_dir="$default_base/cache/oracle-instantclient"
    fi

    mkdir -p "$rpm_dir"

    for package in "${INSTANTCLIENT_PACKAGES[@]}"; do
        local rpm_path="$rpm_dir/$package"
        if [[ -f "$rpm_path" ]]; then
            continue
        fi

        if [[ -z "${ORACLE_INSTANTCLIENT_BASE_URL:-}" ]]; then
            echo "Oracle Instant Client package '$package' is missing from '$rpm_dir'." >&2
            echo "Download the RPMs manually or set ORACLE_INSTANTCLIENT_BASE_URL to an accessible mirror." >&2
            exit 1
        fi

        ensure_download_tool
        local url="${ORACLE_INSTANTCLIENT_BASE_URL%/}/$package"
        echo "Downloading $package from $url" >&2
        if ! fetch_package "$url" "$rpm_path"; then
            echo "Failed to download $package from $url" >&2
            exit 1
        fi
    done

    printf '%s\n' "$rpm_dir"
}

ensure_alien_available() {
    if ! command -v alien >/dev/null 2>&1; then
        echo "The 'alien' utility is required to install Oracle Instant Client RPMs on Ubuntu." >&2
        echo "Install it with: sudo apt-get install -y alien" >&2
        exit 1
    fi
}

install_instantclient_rpms() {
    local rpm_dir
    rpm_dir=$(resolve_instantclient_rpm_dir)
    local package base_name rpm_path

    ensure_alien_available

    for package in "${INSTANTCLIENT_PACKAGES[@]}"; do
        rpm_path="$rpm_dir/$package"
        if [[ ! -f "$rpm_path" ]]; then
            echo "Expected RPM '$rpm_path' was not found." >&2
            exit 1
        fi

        base_name=${package%%-${INSTANTCLIENT_RELEASE}*}
        if ! dpkg-query -W -f='${Status}' "$base_name" >/dev/null 2>&1; then
            alien --scripts -i "$rpm_path"
        else
            # Reinstall silently to ensure the desired version is present.
            alien --scripts -i "$rpm_path"
        fi
    done
}
