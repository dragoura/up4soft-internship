#!/usr/bin/env bash
set -euo pipefail
# Preserve our own location even if common.sh redefines script_dir
self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$self_dir/lib/common.sh"

# Load SSL-specific overrides/additions (required) from the script's directory
ssl_env_path="$self_dir/config_ssl.env"
if [[ ! -f "$ssl_env_path" ]]; then
  log "ERROR: Missing SSL config: $ssl_env_path"
  exit 1
fi
# shellcheck disable=SC1091
source "$ssl_env_path"

site_name="${SITE_NAME:?}"
certbot_email="${CERTBOT_EMAIL:?}"
webroot_path="${WEBROOT_PATH:-/var/www/letsencrypt}"
nginx_web_root="${NGINX_WEB_ROOT:-/var/www/javaapp}"
redirect_http="${REDIRECT_HTTP_TO_HTTPS:-true}"
site_conf_ssl_src="${SITE_CONF_SSL_SRC:-}"

apt_install nginx certbot python3-certbot-nginx
ensure_dir "$webroot_path" www-data www-data 0755
ensure_dir "$nginx_web_root" www-data www-data 0755

# Phase 1: ensure HTTP-only ACME config in place for issuance
acme_conf="/etc/nginx/sites-available/${site_name}-acme"
cat >"/tmp/${site_name}-acme.conf" <<EOF
server {
    listen 80;
    server_name ${site_name};

    location /.well-known/acme-challenge/ {
        root ${webroot_path};
    }

    # Minimal handler for any other path during issuance
    location / {
        return 404;
    }
}
EOF
as_root mv "/tmp/${site_name}-acme.conf" "$acme_conf"
as_root ln -sf "$acme_conf" "/etc/nginx/sites-enabled/${site_name}"
as_root rm -f /etc/nginx/sites-enabled/default || true
as_root nginx -t
as_root systemctl reload nginx

# Phase 2: obtain/renew certificate via webroot
if [[ ! -f "/etc/letsencrypt/live/${site_name}/fullchain.pem" ]]; then
  log "Obtaining certificate via webroot for ${site_name} ..."
  as_root certbot certonly --webroot -w "$webroot_path" -d "$site_name" \
    --non-interactive --agree-tos -m "$certbot_email" --keep-until-expiring
else
  log "Certificate already present, keeping until expiring."
fi

# Phase 3: install final SSL-enabled nginx config
final_conf="/etc/nginx/sites-available/${site_name}"
if [[ -n "$site_conf_ssl_src" && -f "$site_conf_ssl_src" ]]; then
  as_root cp -f "$site_conf_ssl_src" "$final_conf"
else
  tmp_final="/tmp/${site_name}.conf"
  cat >"$tmp_final" <<EOF
server {
    listen 80;
    server_name ${site_name};
$(if [[ "${redirect_http,,}" == "true" ]]; then
  cat <<'REDIR'
    return 301 https://$host$request_uri;
REDIR
else
  cat <<REDIR
    location /.well-known/acme-challenge/ {
        root ${webroot_path};
    }
REDIR
fi)
}

server {
    listen 443 ssl http2;
    server_name ${site_name};

    ssl_certificate /etc/letsencrypt/live/${site_name}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${site_name}/privkey.pem;

    root ${nginx_web_root}/build;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_buffering off;
    }
}
EOF
  as_root mv "$tmp_final" "$final_conf"
fi

as_root ln -sf "$final_conf" "/etc/nginx/sites-enabled/${site_name}"
as_root nginx -t
as_root systemctl reload nginx
log "Nginx SSL configured for ${site_name}."


