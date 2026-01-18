#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"
require_root

user="${APP_USER:-julia}"
pubkey="${SSH_PUBLIC_KEY_PATH:-}"
pwls="${ENABLE_PASSWORDLESS_SUDO:-false}"

log "Creating user '$user' (if missing) and adding to sudo..."
if ! id "$user" &>/dev/null; then
  adduser --disabled-password --gecos "" "$user"
fi
usermod -aG sudo "$user"

home_dir="$(user_home "$user")"
ensure_dir "$home_dir/.ssh" "$user" "$user" 0700
if [[ -n "$pubkey" && -f "$pubkey" ]]; then
  cat "$pubkey" >> "$home_dir/.ssh/authorized_keys"
  chown "$user:$user" "$home_dir/.ssh/authorized_keys"
  chmod 0600 "$home_dir/.ssh/authorized_keys"
else
  log "WARNING: SSH public key not provided or not found: $pubkey"
fi

if [[ "${pwls,,}" == "true" ]]; then
  echo "$user ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/"$user"
  chmod 0440 /etc/sudoers.d/"$user"
  visudo -cf /etc/sudoers.d/"$user" >/dev/null
fi

log "Bootstrap complete."

