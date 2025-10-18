#!/bin/bash

set -euo pipefail

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

cd /u01/app/oracle/product/21/dbhome_1/lib/stubs
rm -f libc.*
cd /u01/app/oracle/product/21/dbhome_1/bin
./relink all
