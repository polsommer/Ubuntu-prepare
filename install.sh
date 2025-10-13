#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$SCRIPT_DIR
STATE_ROOT_DEFAULT=/var/lib/swg-prepare
STATE_ROOT=${STATE_ROOT:-$STATE_ROOT_DEFAULT}
FORCE=false
DRY_RUN=false
RUN_OCI8=true
RUN_SERVICE=true

usage() {
    cat <<'USAGE'
Usage: install.sh [options]

Automates provisioning of the Oracle database prerequisites, SWG tooling
stack, and supporting services provided by this repository.

Options:
  --force          Re-run every step even if it was completed previously.
  --dry-run        Show the actions that would be executed without running them.
  --skip-oci8      Do not install the PHP OCI8 extension.
  --skip-service   Skip deployment of the Oracle service unit files.
  --state-dir DIR  Override the directory used to persist step completion marks.
  -h, --help       Display this help message.
USAGE
}

while (($#)); do
    case $1 in
        --force)
            FORCE=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --skip-oci8)
            RUN_OCI8=false
            ;;
        --skip-service)
            RUN_SERVICE=false
            ;;
        --state-dir)
            shift || { echo "Missing argument for --state-dir" >&2; exit 1; }
            STATE_ROOT=$1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift || true
done

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_root() {
    if [[ $(id -u) -ne 0 ]]; then
        echo "This installer must be run as root." >&2
        exit 1
    fi
}

trap 'log "ERROR: installation aborted (line $LINENO)."' ERR

require_root

mkdir -p "$STATE_ROOT"

mark_step() {
    local key=$1
    touch "$STATE_ROOT/$key.done"
}

has_run_step() {
    local key=$1
    [[ -f "$STATE_ROOT/$key.done" ]]
}

run_command() {
    if [[ $DRY_RUN == true ]]; then
        log "DRY-RUN: $*"
        return 0
    else
        "$@"
    fi
}

run_step() {
    local key=$1
    shift
    local description=$1
    shift
    local check_fn=$1
    shift
    local cmd=("$@")

    if [[ $FORCE == false && $check_fn != "-" ]]; then
        if "$check_fn"; then
            log "Skipping $description (already satisfied)."
            if [[ $DRY_RUN == false ]]; then
                mark_step "$key"
            fi
            return
        fi
    fi

    if [[ $FORCE == false ]] && has_run_step "$key"; then
        log "Skipping $description (marked complete)."
        return
    fi

    log "Starting: $description"
    run_command "${cmd[@]}"
    if [[ $DRY_RUN == false ]]; then
        mark_step "$key"
        log "Completed: $description"
    else
        log "Simulated: $description"
    fi
}

oracle_home_ready() {
    [[ -d /u01/app/oracle/product/21/dbhome_1 ]]
}

azul_jdk_ready() {
    [[ -x /opt/zulu/zulu17/bin/java ]]
}

oci8_extension_ready() {
    if ! command -v php >/dev/null 2>&1; then
        return 1
    fi
    php -m | grep -q '^oci8$'
}

service_files_ready() {
    [[ -f /etc/systemd/system/odb.service ]]
}

run_step \
    "oracle-prereqs" \
    "Oracle database prerequisites" \
    oracle_home_ready \
    "$REPO_ROOT/oinit.sh"

run_step \
    "oracle-relink" \
    "Relink Oracle binaries" \
    - \
    "$REPO_ROOT/orelink.sh"

run_step \
    "swg-tooling" \
    "Install SWG tooling stack" \
    azul_jdk_ready \
    "$REPO_ROOT/swginit.sh"

if [[ $RUN_OCI8 == true ]]; then
    run_step \
        "php-oci8" \
        "Provision PHP OCI8 extension" \
        oci8_extension_ready \
        "$REPO_ROOT/oci8.sh"
else
    log "Skipping PHP OCI8 installation by request."
fi

if [[ $RUN_SERVICE == true ]]; then
    run_step \
        "odb-service" \
        "Install Oracle database service unit" \
        service_files_ready \
        "$REPO_ROOT/oservice.sh"
else
    log "Skipping service deployment by request."
fi

log "All requested steps have completed."
