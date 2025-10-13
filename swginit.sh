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
    "oracle-instantclient-basiclite-${INSTANTCLIENT_RELEASE}.i386.rpm|https://download.oracle.com/otn_software/linux/instantclient/211800/oracle-instantclient-basiclite-${INSTANTCLIENT_RELEASE}.i386.rpm"
    "oracle-instantclient-devel-${INSTANTCLIENT_RELEASE}.i386.rpm|https://download.oracle.com/otn_software/linux/instantclient/211800/oracle-instantclient-devel-${INSTANTCLIENT_RELEASE}.i386.rpm"
    "oracle-instantclient-sqlplus-${INSTANTCLIENT_RELEASE}.i386.rpm|https://download.oracle.com/otn_software/linux/instantclient/211800/oracle-instantclient-sqlplus-${INSTANTCLIENT_RELEASE}.i386.rpm"
)

if [[ -n "${INSTANTCLIENT_COMPONENTS_OVERRIDE:-}" ]]; then
    mapfile -t INSTANTCLIENT_COMPONENTS <<<"${INSTANTCLIENT_COMPONENTS_OVERRIDE}"
fi

AZUL_ZULU_JDK_TARBALL=${AZUL_ZULU_JDK_TARBALL:-zulu17.46.19-ca-jdk17.0.10-linux_i686.tar.gz}
AZUL_ZULU_JDK_URL=${AZUL_ZULU_JDK_URL:-https://cdn.azul.com/zulu/bin/${AZUL_ZULU_JDK_TARBALL}}
AZUL_ZULU_CACHE_DIR=${AZUL_ZULU_CACHE_DIR:-/tmp/azul-zulu}
AZUL_ZULU_INSTALL_ROOT=${AZUL_ZULU_INSTALL_ROOT:-/opt/zulu}

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

install_azul_zulu_jdk() {
    local tarball_name=$AZUL_ZULU_JDK_TARBALL
    local tarball_url=$AZUL_ZULU_JDK_URL
    local cache_dir=$AZUL_ZULU_CACHE_DIR
    local install_root=$AZUL_ZULU_INSTALL_ROOT
    local tarball_path="$cache_dir/$tarball_name"

    mkdir -p "$cache_dir"
    if [[ ! -f "$tarball_path" ]]; then
        echo -e "\n💡 Installing 32-bit Azul Zulu JDK 17 on openSUSE...\n"
        wget -O "$tarball_path" "$tarball_url"
    fi

    if [[ ! -f "$tarball_path" ]]; then
        echo "Unable to locate the Azul Zulu JDK archive at $tarball_path" >&2
        exit 1
    fi

    mkdir -p "$install_root"

    local extracted_dir
    if ! extracted_dir=$(tar -tf "$tarball_path" | head -1 | cut -d/ -f1); then
        echo "Unable to inspect the Azul Zulu JDK archive at $tarball_path" >&2
        exit 1
    fi
    if [[ -z "$extracted_dir" ]]; then
        echo "Unable to determine the Azul Zulu JDK extraction directory from $tarball_path" >&2
        exit 1
    fi

    local target_dir="$install_root/$extracted_dir"
    if [[ ! -d "$target_dir" ]]; then
        tar -xzf "$tarball_path" -C "$install_root"
    fi

    ln -sfn "$target_dir" "$install_root/zulu17"

    append_unique "export JAVA_HOME=${install_root}/zulu17" /etc/profile.d/java.sh
    append_unique 'export PATH=$JAVA_HOME/bin:$PATH' /etc/profile.d/java.sh
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
    tar \
    zlib-devel \
    zlib-devel-32bit

install_optional_packages \
    boost-devel \
    libboost_program_options1_82_0 \
    libboost_program_options1_82_0-32bit

# Acquire and install the Oracle Instant Client components required by SWG tooling
download_instantclient_rpms
install_instantclient_rpms
resolve_instantclient_layout

# Install and expose a 32-bit Azul Zulu JDK 17 runtime for the SWG tooling stack
install_azul_zulu_jdk

# set env vars
append_unique "${INSTANTCLIENT_LIB}" /etc/ld.so.conf.d/oracle.conf
append_unique "export ORACLE_HOME=${INSTANTCLIENT_HOME}" /etc/profile.d/oracle.sh
append_unique "export PATH=\$PATH:${INSTANTCLIENT_BIN}" /etc/profile.d/oracle.sh
append_unique "export LD_LIBRARY_PATH=${INSTANTCLIENT_LIB}:${INSTANTCLIENT_INCLUDE}" /etc/profile.d/oracle.sh

if [[ -d "${INSTANTCLIENT_INCLUDE}" && ! -e "${INSTANTCLIENT_HOME}/include" ]]; then
    ln -s "${INSTANTCLIENT_INCLUDE}" "${INSTANTCLIENT_HOME}/include"
fi

ldconfig
