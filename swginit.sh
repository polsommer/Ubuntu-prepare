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

map_instantclient_to_azul_suffix() {
    local arch=$1
    case "$arch" in
        i386)
            printf 'i686\n'
            ;;
        aarch64)
            printf 'aarch64\n'
            ;;
        *)
            printf 'x64\n'
            ;;
    esac
}

describe_azul_arch() {
    local suffix=$1
    case "$suffix" in
        i686)
            printf '32-bit (linux_i686)\n'
            ;;
        x64)
            printf '64-bit (linux_x64)\n'
            ;;
        aarch64)
            printf 'ARM64 (linux_aarch64)\n'
            ;;
        *)
            printf 'linux_%s\n' "$suffix"
            ;;
    esac
}

INSTANTCLIENT_ARCH=${INSTANTCLIENT_ARCH:-$(detect_default_instantclient_arch)}
INSTANTCLIENT_BASE_URL=${INSTANTCLIENT_BASE_URL:-$DEFAULT_INSTANTCLIENT_BASE_URL}
AZUL_ZULU_SUFFIX=${AZUL_ZULU_SUFFIX:-$(map_instantclient_to_azul_suffix "$INSTANTCLIENT_ARCH")}

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

AZUL_ZULU_JDK_TARBALL=${AZUL_ZULU_JDK_TARBALL:-zulu17.46.19-ca-jdk17.0.10-linux_${AZUL_ZULU_SUFFIX}.tar.gz}
AZUL_ZULU_JDK_URL=${AZUL_ZULU_JDK_URL:-https://cdn.azul.com/zulu/bin/${AZUL_ZULU_JDK_TARBALL}}
AZUL_ZULU_CACHE_DIR=${AZUL_ZULU_CACHE_DIR:-/tmp/azul-zulu}
AZUL_ZULU_INSTALL_ROOT=${AZUL_ZULU_INSTALL_ROOT:-/opt/zulu}

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

install_optional_packages() {
    local pkg
    for pkg in "$@"; do
        if ! apt-get install -y --no-install-recommends "$pkg"; then
            echo "Optional package '$pkg' could not be installed; continuing." >&2
        fi
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

install_azul_zulu_jdk() {
    local tarball_name=$AZUL_ZULU_JDK_TARBALL
    local tarball_url=$AZUL_ZULU_JDK_URL
    local cache_dir=$AZUL_ZULU_CACHE_DIR
    local install_root=$AZUL_ZULU_INSTALL_ROOT
    local tarball_path="$cache_dir/$tarball_name"

    mkdir -p "$cache_dir"
    if [[ ! -f "$tarball_path" ]]; then
        local arch_description
        arch_description=$(describe_azul_arch "$AZUL_ZULU_SUFFIX")
        echo -e "\n💡 Installing Azul Zulu JDK 17 ${arch_description} on Ubuntu...\n"
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

ensure_ubuntu_24
ensure_required_architecture
refresh_repos

packages=(
    alien
    ant
    bc
    bison
    build-essential
    clang
    cmake
    flex
    gcc
    g++
    gcc-multilib
    git
    libaio1
    libnsl2
    libcurl4
    libgcc-s1
    libstdc++6
    libncurses5
    libpcre3
    libsqlite3-0
    libxml2
    linux-libc-dev
    perl
    psmisc
    python3-ply
    sqlite3
    tar
    zlib1g-dev
    pkg-config
)

if [[ "$INSTANTCLIENT_ARCH" == "i386" ]]; then
    packages+=(
        libaio1:i386
        libnsl2:i386
        libcurl4:i386
        libgcc-s1:i386
        libstdc++6:i386
        libncurses5:i386
        libpcre3:i386
        libsqlite3-0:i386
        libxml2:i386
        zlib1g:i386
    )
fi

install_packages "${packages[@]}"

optional_packages=(
    libboost-program-options-dev
    libboost-program-options1.83.0
)

if [[ "$INSTANTCLIENT_ARCH" == "i386" ]]; then
    optional_packages+=(
        libboost-program-options1.83.0:i386
    )
fi

install_optional_packages "${optional_packages[@]}"

# Acquire and install the Oracle Instant Client components required by SWG tooling
download_instantclient_rpms
install_instantclient_rpms
resolve_instantclient_layout

# Install and expose the Azul Zulu JDK 17 runtime for the SWG tooling stack
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
