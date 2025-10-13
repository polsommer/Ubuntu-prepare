#!/bin/bash

set -euo pipefail

INSTANTCLIENT_MAJOR=${INSTANTCLIENT_MAJOR:-21}
INSTANTCLIENT_RELEASE=${INSTANTCLIENT_RELEASE:-21.18.0.0.0-1}
INSTANTCLIENT_ARCH=${INSTANTCLIENT_ARCH:-i386}
INSTANTCLIENT_HOME=${INSTANTCLIENT_HOME:-/usr/lib/oracle/${INSTANTCLIENT_MAJOR}/client32}
INSTANTCLIENT_LIB=${INSTANTCLIENT_LIB:-${INSTANTCLIENT_HOME}/lib}
INSTANTCLIENT_BIN=${INSTANTCLIENT_BIN:-${INSTANTCLIENT_HOME}/bin}
INSTANTCLIENT_INCLUDE=${INSTANTCLIENT_INCLUDE:-/usr/include/oracle/${INSTANTCLIENT_MAJOR}/client32}

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

install_instantclient_rpms() {
    local rpm_dir
    rpm_dir=$(resolve_instantclient_rpm_dir)
    local package

    for package in "${INSTANTCLIENT_PACKAGES[@]}"; do
        local rpm_path="$rpm_dir/$package"
        if [[ ! -f "$rpm_path" ]]; then
            echo "Expected RPM '$rpm_path' was not found." >&2
            exit 1
        fi
        zypper --non-interactive install --allow-unsigned-rpm "$rpm_path"
    done
}
