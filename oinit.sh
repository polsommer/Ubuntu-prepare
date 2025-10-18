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
    "oracle-instantclient-basiclite-${INSTANTCLIENT_RELEASE}.i386.rpm|https://drive.google.com/open?id=1xb0S2cYAmXZurIkzuUuVOPDw-CcjDioL"
    "oracle-instantclient-devel-${INSTANTCLIENT_RELEASE}.i386.rpm|https://drive.google.com/open?id=15s_e_Z4BMxpAqsIUFwyO1tbM9SS1XFVZ"
    "oracle-instantclient-sqlplus-${INSTANTCLIENT_RELEASE}.i386.rpm|https://drive.google.com/open?id=1FUVe89ZObP_LQN63xD1kQEpBgTmV3wbX"
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

install_optional_packages() {
    local pkg
    for pkg in "$@"; do
        if ! apt-get install -y --no-install-recommends "$pkg"; then
            echo "Optional package '$pkg' could not be installed; continuing." >&2
        fi
    done
}

create_group() {
    local group=$1
    if ! getent group "$group" >/dev/null; then
        groupadd "$group"
    fi
}

create_user() {
    local user=$1
    local primary_group=$2
    local secondary_groups=$3
    if ! id "$user" >/dev/null 2>&1; then
        useradd -g "$primary_group" -G "$secondary_groups" -s /bin/bash -m "$user"
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

create_symlink_if_missing() {
    local target=$1
    local link=$2
    if [[ ! -e "$link" ]]; then
        ln -s "$target" "$link"
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
    build-essential \
    alien \
    autoconf \
    automake \
    binutils \
    bzip2 \
    elfutils \
    gawk \
    gcc \
    g++ \
    gcc-multilib \
    libc6 \
    libc6-dev \
    libc6:i386 \
    libc6-dev:i386 \
    libstdc++6 \
    libstdc++6:i386 \
    libgcc-s1 \
    libgcc-s1:i386 \
    libexpat1 \
    libexpat1-dev \
    ksh \
    less \
    libaio-dev \
    libaio1 \
    libaio1:i386 \
    libnsl-dev \
    libnsl2 \
    libnsl2:i386 \
    libelf-dev \
    libltdl7 \
    libmotif-dev \
    perl \
    rlwrap \
    rpm \
    sysstat \
    unixodbc \
    unixodbc-dev \
    unzip \
    wget \
    zenity \
    zlib1g-dev \
    zlib1g:i386 \
    pkg-config \
    libx11-6 \
    libx11-6:i386 \
    libxext6 \
    libxext6:i386 \
    libxft2 \
    libxft2:i386 \
    libxi6 \
    libxi6:i386 \
    libxtst6 \
    libxtst6:i386 \
    libxt6 \
    libxt6:i386

install_optional_packages \
    libmrm4 \
    libmrm4:i386 \
    libuil4 \
    libuil4:i386 \
    libxm4 \
    libxm4:i386

# Setup groups and an oracle user
create_group oinstall
create_group dba
create_group oper
create_group nobody
create_group asmadmin
create_user oracle oinstall "dba,asmadmin,oper"
echo "oracle:swg" | chpasswd

# Edit Parameters
append_unique '#### Oracle Kernel Parameters ####' /etc/sysctl.conf
append_unique 'fs.suid_dumpable = 1' /etc/sysctl.conf
append_unique 'fs.aio-max-nr = 1048576' /etc/sysctl.conf
append_unique 'fs.file-max = 6815744' /etc/sysctl.conf
append_unique 'kernel.shmall = 818227' /etc/sysctl.conf
append_unique 'kernel.shmmax = 4189323264' /etc/sysctl.conf
append_unique 'kernel.shmmni = 4096' /etc/sysctl.conf
append_unique 'kernel.panic_on_oops = 1' /etc/sysctl.conf
append_unique 'kernel.sem = 250 32000 100 128' /etc/sysctl.conf
append_unique 'net.ipv4.ip_local_port_range = 9000 65500' /etc/sysctl.conf
append_unique 'net.core.rmem_default=262144' /etc/sysctl.conf
append_unique 'net.core.rmem_max=4194304' /etc/sysctl.conf
append_unique 'net.core.wmem_default=262144' /etc/sysctl.conf
append_unique 'net.core.wmem_max=1048576' /etc/sysctl.conf

append_unique '#### Oracle User Settings ####' /etc/security/limits.conf
append_unique 'oracle       soft  nproc  2047' /etc/security/limits.conf
append_unique 'oracle       hard  nproc  16384' /etc/security/limits.conf
append_unique 'oracle       soft  nofile 1024' /etc/security/limits.conf
append_unique 'oracle       hard  nofile 65536' /etc/security/limits.conf
append_unique 'oracle       soft  stack  10240' /etc/security/limits.conf

sysctl -p

# Set symlinks
create_symlink_if_missing /usr/bin/awk /bin/awk
create_symlink_if_missing /usr/bin/rpm /bin/rpm
create_symlink_if_missing /usr/bin/basename /bin/basename
create_symlink_if_missing /usr/lib/x86_64-linux-gnu /usr/lib64
create_symlink_if_missing /lib/x86_64-linux-gnu /lib64
ln -sf /bin/bash /bin/sh

# Set Paths in Oracle bashrc
append_unique '# Oracle Settings' /home/oracle/.bashrc
append_unique 'export TMP=/tmp;' /home/oracle/.bashrc
append_unique 'export TMPDIR=$TMP;' /home/oracle/.bashrc
append_unique 'export ORACLE_HOSTNAME=swg;' /home/oracle/.bashrc
append_unique 'export ORACLE_BASE=/u01/app/oracle;' /home/oracle/.bashrc
append_unique 'export ORACLE_HOME=$ORACLE_BASE/product/21/dbhome_1;' /home/oracle/.bashrc
append_unique 'export ORACLE_SID=swg;' /home/oracle/.bashrc
append_unique 'export ORACLE_UNQNAME=$ORACLE_SID;' /home/oracle/.bashrc
append_unique 'export PATH=/usr/sbin:$ORACLE_HOME/bin:$PATH;' /home/oracle/.bashrc
append_unique 'export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu;' /home/oracle/.bashrc
append_unique 'export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib;' /home/oracle/.bashrc

# let's download and unpack the binary
wget https://github.com/tekaohswg/gdown.pl/archive/v1.4.zip
unzip v1.4.zip
rm v1.4.zip
./gdown.pl-1.4/gdown.pl 'https://drive.google.com/open?id=17wfbfZuL90z4Z_FZPHK7l8FecepZ3dyP' 'LINUX.X64_213000_db_home.zip'
rm -r gdown.pl-1.4
mkdir -p /u01/app/oracle/product/21/dbhome_1
unzip -d /u01/app/oracle/product/21/dbhome_1/ LINUX.X64_213000_db_home.zip
chown -R oracle:oinstall /u01

# Acquire and install the Oracle Instant Client dependencies required by tooling
download_instantclient_rpms
install_instantclient_rpms
resolve_instantclient_layout

append_unique "${INSTANTCLIENT_LIB}" /etc/ld.so.conf.d/oracle.conf
append_unique "export ORACLE_HOME=${INSTANTCLIENT_HOME}" /etc/profile.d/oracle.sh
append_unique "export PATH=\$PATH:${INSTANTCLIENT_BIN}" /etc/profile.d/oracle.sh
append_unique "export LD_LIBRARY_PATH=${INSTANTCLIENT_LIB}:${INSTANTCLIENT_INCLUDE}" /etc/profile.d/oracle.sh

if [[ -d "${INSTANTCLIENT_INCLUDE}" && ! -e "${INSTANTCLIENT_HOME}/include" ]]; then
    ln -s "${INSTANTCLIENT_INCLUDE}" "${INSTANTCLIENT_HOME}/include"
fi

ldconfig
chmod -R 775 /u01
