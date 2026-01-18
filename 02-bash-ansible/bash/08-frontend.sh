#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

user="${APP_USER:-julia}"
user_home="$(user_home "$user")"
frontend_dir="${FRONTEND_PROJECT_DIR:-$user_home/Java-app/front-end}"
node_version="${NODE_VERSION:-22.9.0}"
npm_version="${NPM_VERSION:-10.8.3}"
nginx_web_root="${NGINX_WEB_ROOT:-/var/www/ansible}"

apt_install curl ca-certificates

log "Installing NVM for user ${user} ..."
current_user="$(id -un)"
if [[ "$current_user" == "$user" ]]; then
  bash -lc 'export PROFILE="$HOME/.bashrc"; curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
else
sudo -u "$user" -H bash -lc 'export PROFILE="$HOME/.bashrc"; curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
fi

log "Installing Node ${node_version} and npm ${npm_version} via NVM ..."
if [[ "$current_user" == "$user" ]]; then
  bash -lc ". \"\$HOME/.nvm/nvm.sh\" && nvm install '${node_version}' && nvm alias default '${node_version}' && npm i -g npm@'${npm_version}'"
else
sudo -u "$user" -H bash -lc ". \"\$HOME/.nvm/nvm.sh\" && nvm install '${node_version}' && nvm alias default '${node_version}' && npm i -g npm@'${npm_version}'"
fi

log "Writing frontend .env ..."
if [[ "$current_user" == "$user" ]]; then
  bash -lc "mkdir -p '${frontend_dir}'"
  bash -lc "printf 'REACT_APP_API_BASE_URL=%s\n' '${REACT_APP_API_BASE_URL:-https://ansible.julia-b.work}' > '${frontend_dir}/.env'"
else
sudo -u "$user" -H bash -lc "mkdir -p '${frontend_dir}'"
sudo -u "$user" -H bash -lc "printf 'REACT_APP_API_BASE_URL=%s\n' '${REACT_APP_API_BASE_URL:-https://ansible.julia-b.work}' > '${frontend_dir}/.env'"
fi

log "Installing frontend dependencies and building ..."
if [[ "$current_user" == "$user" ]]; then
  if test -f "${frontend_dir}/package-lock.json"; then
    bash -lc ". \"\$HOME/.nvm/nvm.sh\" && cd '${frontend_dir}' && npm ci"
  else
    bash -lc ". \"\$HOME/.nvm/nvm.sh\" && cd '${frontend_dir}' && npm install"
  fi
else
if sudo -u "$user" -H test -f "${frontend_dir}/package-lock.json"; then
  sudo -u "$user" -H bash -lc ". \"\$HOME/.nvm/nvm.sh\" && cd '${frontend_dir}' && npm ci"
else
  sudo -u "$user" -H bash -lc ". \"\$HOME/.nvm/nvm.sh\" && cd '${frontend_dir}' && npm install"
fi
fi
if [[ "$current_user" == "$user" ]]; then
  bash -lc ". \"\$HOME/.nvm/nvm.sh\" && cd '${frontend_dir}' && npm run build"
else
sudo -u "$user" -H bash -lc ". \"\$HOME/.nvm/nvm.sh\" && cd '${frontend_dir}' && npm run build"
fi

log "Deploying frontend build to Nginx web root ..."
ensure_dir "$nginx_web_root" www-data www-data 0755
as_root rm -rf "${nginx_web_root}/build"
as_root cp -a "${frontend_dir}/build" "${nginx_web_root}/build"
as_root chown -R www-data:www-data "${nginx_web_root}/build"
log "Frontend deployed."

