#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

if [[ "${INSTALL_REDIS:-true}" != "true" ]]; then
  log "Skipping Redis install by config."
  exit 0
fi

apt_install redis-server
as_root systemctl enable --now redis-server
log "Redis installed and started."

