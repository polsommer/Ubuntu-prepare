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

ensure_opensuse_16
refresh_repos

zypper --non-interactive install --type pattern devel_basis

install_packages \
    alien \
    autoconf \
    automake \
    binutils \
    bzip2 \
    elfutils \
    expat \
    gawk \
    gcc \
    gcc-c++ \
    gcc-32bit \
    glibc \
    glibc-devel \
    glibc-32bit \
    glibc-devel-32bit \
    ksh \
    less \
    libaio-devel \
    libaio1 \
    libelf-devel \
    libltdl7 \
    motif-devel \
    rlwrap \
    rpm \
    sysstat \
    unixODBC \
    unixODBC-devel \
    unzip \
    wget \
    zenity \
    zlib-devel \
    zlib-devel-32bit

install_optional_packages \
    libmrm4 \
    libmrm4-32bit \
    libstdc++5 \
    libstdc++6-32bit \
    libuil4 \
    libuil4-32bit \
    libXm4 \
    libXm4-32bit

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

/sbin/sysctl -p

# Set symlinks
create_symlink_if_missing /usr/bin/awk /bin/awk
create_symlink_if_missing /usr/bin/rpm /bin/rpm
create_symlink_if_missing /usr/bin/basename /bin/basename
create_symlink_if_missing /usr/lib64 /usr/lib/x86_64-linux-gnu
create_symlink_if_missing /lib64 /lib/x86_64-linux-gnu
create_symlink_if_missing /lib64/libgcc_s.so.1 /lib/libgcc_s.so.1
create_symlink_if_missing /lib64/libgcc_s.so.1 /lib/libgcc_s.so
ln -sf /bin/bash /bin/sh

# Set Paths in Oracle bashrc
append_unique '# Oracle Settings' /home/oracle/.bashrc
append_unique 'export TMP=/tmp;' /home/oracle/.bashrc
append_unique 'export TMPDIR=$TMP;' /home/oracle/.bashrc
append_unique 'export ORACLE_HOSTNAME=swg;' /home/oracle/.bashrc
append_unique 'export ORACLE_BASE=/u01/app/oracle;' /home/oracle/.bashrc
append_unique 'export ORACLE_HOME=$ORACLE_BASE/product/18/dbhome_1;' /home/oracle/.bashrc
append_unique 'export ORACLE_SID=swg;' /home/oracle/.bashrc
append_unique 'export ORACLE_UNQNAME=$ORACLE_SID;' /home/oracle/.bashrc
append_unique 'export PATH=/usr/sbin:$ORACLE_HOME/bin:$PATH;' /home/oracle/.bashrc
append_unique 'export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64;' /home/oracle/.bashrc
append_unique 'export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib;' /home/oracle/.bashrc

# let's download and unpack the binary
wget https://github.com/tekaohswg/gdown.pl/archive/v1.4.zip
unzip v1.4.zip
rm v1.4.zip
./gdown.pl-1.4/gdown.pl 'https://drive.google.com/open?id=17wfbfZuL90z4Z_FZPHK7l8FecepZ3dyP' 'LINUX.X64_180000_db_home.zip'
./gdown.pl-1.4/gdown.pl 'https://drive.google.com/open?id=1xb0S2cYAmXZurIkzuUuVOPDw-CcjDioL' 'oracle-instantclient12.2-basiclite-12.2.0.1.0-1.i386.rpm'
./gdown.pl-1.4/gdown.pl 'https://drive.google.com/open?id=15s_e_Z4BMxpAqsIUFwyO1tbM9SS1XFVZ' 'oracle-instantclient12.2-devel-12.2.0.1.0-1.i386.rpm'
./gdown.pl-1.4/gdown.pl 'https://drive.google.com/open?id=1FUVe89ZObP_LQN63xD1kQEpBgTmV3wbX' 'oracle-instantclient12.2-sqlplus-12.2.0.1.0-1.i386.rpm'
rm -r gdown.pl-1.4
mkdir -p /u01/app/oracle/product/18/dbhome_1
unzip -d /u01/app/oracle/product/18/dbhome_1/ LINUX.X64_180000_db_home.zip
chown -R oracle:oinstall /u01
chmod -R 775 /u01
