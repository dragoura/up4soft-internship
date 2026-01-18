#!/usr/bin/env bash
set -euo pipefail

server="${SERVER:-${1:-}}"
if [[ -z "$server" ]]; then
  echo "ERROR: SERVER not provided. Set env SERVER or pass as first arg." >&2
  exit 1
fi

# Absolute local paths (edit if needed)
LOCAL_PROJECT_ROOT="/Users/yuliya/Up4Soft/03-bash-ansible"
LOCAL_BASH_DIR="${LOCAL_PROJECT_ROOT}/bash"
LOCAL_NGINX_CONF="${LOCAL_BASH_DIR}/bash.julia-b.work.conf"
LOCAL_KEY_PRIV="/Users/yuliya/.ssh/id_ed25519_gitdeploy"
LOCAL_KEY_PUB="/Users/yuliya/.ssh/id_ed25519_gitdeploy.pub"

# Remote paths (absolute to avoid ~ expansion differences across users)
# Use /opt so both root and julia can access the project
REMOTE_ROOT_PROJECT_DIR="/opt/bash-task"
REMOTE_BASH_DIR="${REMOTE_ROOT_PROJECT_DIR}/bash"
REMOTE_KEY_DIR="/home/julia/.ssh"
REMOTE_KEY_PRIV="${REMOTE_KEY_DIR}/id_ed25519"
REMOTE_KEY_PUB="${REMOTE_KEY_DIR}/id_ed25519.pub"
REMOTE_NGINX_CONF="${REMOTE_BASH_DIR}/bash.julia-b.work.conf"

echo "=== Sanity checks ==="
[[ -d "$LOCAL_BASH_DIR" ]] || { echo "Missing $LOCAL_BASH_DIR"; exit 1; }
[[ -f "$LOCAL_NGINX_CONF" ]] || { echo "Missing $LOCAL_NGINX_CONF"; exit 1; }
[[ -f "$LOCAL_KEY_PRIV" ]] || { echo "Missing $LOCAL_KEY_PRIV"; exit 1; }
[[ -f "$LOCAL_KEY_PUB" ]] || { echo "Missing $LOCAL_KEY_PUB"; exit 1; }
if [[ ! -f "${LOCAL_BASH_DIR}/config.env" ]]; then
  echo "WARNING: ${LOCAL_BASH_DIR}/config.env not found. Make sure it exists before running remote steps."
fi

echo "=== 1) Upload project bash directory and nginx config ==="
ssh "$server" "sudo mkdir -p '${REMOTE_ROOT_PROJECT_DIR}'"
scp -r "$LOCAL_BASH_DIR" "$server":"${REMOTE_ROOT_PROJECT_DIR}/"
# Ensure the nginx config is present at the path referenced in SITE_CONF_SRC
scp "$LOCAL_NGINX_CONF" "$server":"${REMOTE_NGINX_CONF}"
ssh "$server" "sudo find '${REMOTE_BASH_DIR}' -type f -name '*.sh' -exec chmod +x {} +"
ssh "$server" "sudo chmod -R a+rX '${REMOTE_ROOT_PROJECT_DIR}'"

echo "=== 2) Create julia user (bootstrap) ==="
ssh "$server" "sudo bash '${REMOTE_BASH_DIR}/00-bootstrap.sh'"

echo "=== 3) Upload Git SSH key into julia's home and install authorized_keys ==="
ssh "$server" "sudo install -d -m 700 -o julia -g julia '/home/julia/.ssh'"
scp "$LOCAL_KEY_PRIV" "$server":"${REMOTE_KEY_PRIV}"
scp "$LOCAL_KEY_PUB" "$server":"${REMOTE_KEY_PUB}"
ssh "$server" "sudo chown julia:julia '${REMOTE_KEY_PRIV}' '${REMOTE_KEY_PUB}' && sudo chmod 600 '${REMOTE_KEY_PRIV}' && sudo chmod 644 '${REMOTE_KEY_PUB}'"
ssh "$server" "sudo bash -lc 'cat \"${REMOTE_KEY_PUB}\" >> \"/home/julia/.ssh/authorized_keys\" && chown julia:julia \"/home/julia/.ssh/authorized_keys\" && chmod 600 \"/home/julia/.ssh/authorized_keys\"'"

echo "=== 4) Apply SSH hardening and firewall (root) ==="
ssh "$server" "sudo bash '${REMOTE_BASH_DIR}/01-ssh-hardening.sh'"
ssh "$server" "sudo bash '${REMOTE_BASH_DIR}/02-firewall.sh'"

# Remaining scripts: run as julia (they sudo only when privileged)
for step in 03-postgresql.sh 04-redis.sh 05-nginx.sh 06-backend-install.sh 07-backend-deploy.sh 08-frontend.sh; do
  echo "=== Running ${step} ==="
  ssh "$server" "sudo -u julia -H bash '${REMOTE_BASH_DIR}/${step}'"
  echo "=== ${step} OK ==="
done

echo "=== All done. ==="


