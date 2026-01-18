#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

site_name="${SITE_NAME:?}"
nginx_web_root="${NGINX_WEB_ROOT:-/var/www/ansible}"
site_conf_src="$(expand_path "${SITE_CONF_SRC:?}")"

apt_install nginx
ensure_dir "$nginx_web_root" www-data www-data 0755

[[ -f "$site_conf_src" ]] || { log "ERROR: SITE_CONF_SRC not found: $site_conf_src"; exit 1; }
as_root cp -f "$site_conf_src" "/etc/nginx/sites-available/${site_name}"

as_root ln -sf "/etc/nginx/sites-available/${site_name}" "/etc/nginx/sites-enabled/${site_name}"
as_root rm -f /etc/nginx/sites-enabled/default || true
as_root nginx -t
as_root systemctl reload nginx

log "Nginx configured."

