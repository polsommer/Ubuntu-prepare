#!/bin/bash

set -euo pipefail

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
fi

if [[ "${ID:-}" != "opensuse" && "${ID_LIKE:-}" != *"opensuse"* ]] || [[ "${VERSION_ID:-}" != "16" ]]; then
    echo "This script is limited to openSUSE 16 systems." >&2
    exit 1
fi

cd /u01/app/oracle/product/21/dbhome_1/lib/stubs
rm -f libc.*
cd /u01/app/oracle/product/21/dbhome_1/bin
./relink all
