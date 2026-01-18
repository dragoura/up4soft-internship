#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run() {
  local step="$1"
  echo "=== Running ${step} ==="
  bash "$script_dir/${step}"
  echo "=== ${step} OK ==="
}

steps=(
  "00-bootstrap.sh"
  "01-ssh-hardening.sh"
  "02-firewall.sh"
  "03-postgresql.sh"
  "04-redis.sh"
  "05-nginx.sh"
  "06-backend-install.sh"
  "07-backend-deploy.sh"
  "08-frontend.sh"
)

if [[ $# -gt 0 ]]; then
  steps=("$@")
fi

for s in "${steps[@]}"; do
  run "$s"
done

