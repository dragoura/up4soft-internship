#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"
require_root

if [[ "${ENABLE_UFW:-true}" != "true" ]]; then
  log "UFW enable skipped by config."
  exit 0
fi

apt_install ufw
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
log "UFW enabled with SSH/HTTP allowed."

