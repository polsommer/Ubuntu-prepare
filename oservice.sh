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

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR" && pwd)

cp "$REPO_ROOT/includes/odb/odb.service" /etc/systemd/system/
cp "$REPO_ROOT/includes/odb/odb-start.sh" /etc/
cp "$REPO_ROOT/includes/odb/odb-stop.sh" /etc/
chmod +x /etc/odb-start.sh /etc/odb-stop.sh
systemctl enable odb.service
