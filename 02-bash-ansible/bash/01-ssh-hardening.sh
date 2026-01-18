#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"
require_root

: "${SSH_ALLOW_USERS:?Missing SSH_ALLOW_USERS in config.env}"
allow_users="${SSH_ALLOW_USERS}"
conf_path="/etc/ssh/sshd_config.d/99-ansible.conf"

log "Writing SSH hardening snippet to $conf_path ..."
cat > "$conf_path" <<EOF
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
UsePAM yes
AuthorizedKeysFile %h/.ssh/authorized_keys
AllowUsers ${allow_users}
EOF
chmod 0644 "$conf_path"

log "Validating sshd config ..."
sshd -t

log "Reloading sshd ..."
systemctl reload ssh
log "SSH hardening applied."

