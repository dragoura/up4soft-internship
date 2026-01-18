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
LOCAL_SSL_CONF="${LOCAL_BASH_DIR}/bash.julia-b.work.ssl.conf"
# Local SSH keys
LOCAL_DROPLET_KEY_PRIV="/Users/yuliya/.ssh/id_ed25519_droplet"
LOCAL_DROPLET_KEY_PUB="/Users/yuliya/.ssh/id_ed25519_droplet.pub"
LOCAL_GIT_KEY_PRIV="/Users/yuliya/.ssh/id_ed25519_gitdeploy"
LOCAL_GIT_KEY_PUB="/Users/yuliya/.ssh/id_ed25519_gitdeploy.pub"

# Remote paths
REMOTE_ROOT_PROJECT_DIR="/opt/bash-task"
REMOTE_BASH_DIR="${REMOTE_ROOT_PROJECT_DIR}/bash"
REMOTE_SSL_CONF="${REMOTE_BASH_DIR}/bash.julia-b.work.ssl.conf"
REMOTE_KEY_DIR="/home/julia/.ssh"
# Remote key paths
REMOTE_DROPLET_KEY_PRIV="${REMOTE_KEY_DIR}/id_ed25519_droplet"
REMOTE_DROPLET_KEY_PUB="${REMOTE_KEY_DIR}/id_ed25519_droplet.pub"
REMOTE_GIT_KEY_PRIV="${REMOTE_KEY_DIR}/id_ed25519_gitdeploy"
REMOTE_GIT_KEY_PUB="${REMOTE_KEY_DIR}/id_ed25519_gitdeploy.pub"

echo "=== Sanity checks ==="
[[ -d "$LOCAL_BASH_DIR" ]] || { echo "Missing $LOCAL_BASH_DIR"; exit 1; }
if [[ ! -f "${LOCAL_BASH_DIR}/config_ssl.env" ]]; then
  echo "WARNING: ${LOCAL_BASH_DIR}/config_ssl.env not found. 05_nginx_ssl.sh requires CERTBOT_EMAIL and SITE_NAME."
fi
if [[ ! -f "$LOCAL_SSL_CONF" ]]; then
  echo "INFO: SSL site config $LOCAL_SSL_CONF not found; 05_nginx_ssl.sh will generate a default."
fi
[[ -f "$LOCAL_DROPLET_KEY_PRIV" ]] || { echo "Missing $LOCAL_DROPLET_KEY_PRIV"; exit 1; }
[[ -f "$LOCAL_DROPLET_KEY_PUB" ]] || { echo "Missing $LOCAL_DROPLET_KEY_PUB"; exit 1; }
[[ -f "$LOCAL_GIT_KEY_PRIV" ]] || { echo "Missing $LOCAL_GIT_KEY_PRIV"; exit 1; }
[[ -f "$LOCAL_GIT_KEY_PUB" ]] || { echo "Missing $LOCAL_GIT_KEY_PUB"; exit 1; }

echo "=== 1) Upload project bash directory (SSL assets included) ==="
ssh "$server" "sudo mkdir -p '${REMOTE_ROOT_PROJECT_DIR}'"
scp -r "$LOCAL_BASH_DIR" "$server":"${REMOTE_ROOT_PROJECT_DIR}/"
ssh "$server" "sudo find '${REMOTE_BASH_DIR}' -type f -name '*.sh' -exec chmod +x {} +"
ssh "$server" "sudo chmod -R a+rX '${REMOTE_ROOT_PROJECT_DIR}'"
if [[ -f "$LOCAL_SSL_CONF" ]]; then
  scp "$LOCAL_SSL_CONF" "$server":"${REMOTE_SSL_CONF}"
fi

echo "=== 2) Create julia user (bootstrap) ==="
ssh "$server" "sudo bash '${REMOTE_BASH_DIR}/00-bootstrap.sh'"

echo "=== 3) Upload Git SSH key into julia's home and install authorized_keys ==="
ssh "$server" "sudo install -d -m 700 -o julia -g julia '${REMOTE_KEY_DIR}'"
scp "$LOCAL_DROPLET_KEY_PRIV" "$server":"${REMOTE_DROPLET_KEY_PRIV}"
scp "$LOCAL_DROPLET_KEY_PUB" "$server":"${REMOTE_DROPLET_KEY_PUB}"
scp "$LOCAL_GIT_KEY_PRIV" "$server":"${REMOTE_GIT_KEY_PRIV}"
scp "$LOCAL_GIT_KEY_PUB" "$server":"${REMOTE_GIT_KEY_PUB}"
ssh "$server" "sudo chown julia:julia '${REMOTE_DROPLET_KEY_PRIV}' '${REMOTE_DROPLET_KEY_PUB}' '${REMOTE_GIT_KEY_PRIV}' '${REMOTE_GIT_KEY_PUB}' && sudo chmod 600 '${REMOTE_DROPLET_KEY_PRIV}' '${REMOTE_GIT_KEY_PRIV}' && sudo chmod 644 '${REMOTE_DROPLET_KEY_PUB}' '${REMOTE_GIT_KEY_PUB}'"
# Idempotently add DROPLET public key to authorized_keys for shell access
ssh "$server" "sudo bash -lc 'auth=\"${REMOTE_KEY_DIR}/authorized_keys\"; pub=\"${REMOTE_DROPLET_KEY_PUB}\"; touch \"\$auth\"; chown julia:julia \"\$auth\"; chmod 600 \"\$auth\"; if [[ -f \"\$pub\" ]] && ! grep -qxF -f \"\$pub\" \"\$auth\" 2>/dev/null; then cat \"\$pub\" >> \"\$auth\"; fi'"

echo "=== 4) Apply SSH hardening and firewall (root) ==="
ssh "$server" "sudo bash '${REMOTE_BASH_DIR}/01-ssh-hardening.sh'"
ssh "$server" "sudo bash '${REMOTE_BASH_DIR}/02-firewall.sh'"

echo "=== 5) Run app setup steps as julia (with SSL) ==="
for step in 03-postgresql.sh 04-redis.sh 05_nginx_ssl.sh 06-backend-install.sh 07-backend-deploy.sh 08-frontend.sh; do
  echo "=== Running ${step} ==="
  ssh "$server" "sudo -u julia -H bash '${REMOTE_BASH_DIR}/${step}'"
  echo "=== ${step} OK ==="
done

echo "=== SSL deploy complete. ==="


