#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

user="${APP_USER:-julia}"
user_home="$(user_home "$user")"
backend_project_dir="${BACKEND_PROJECT_DIR:-$user_home/Java-app/back-end}"
backend_jar_name="${BACKEND_JAR_NAME:-ci-back-end-0.0.1-SNAPSHOT.jar}"
javaapp_dir="${JAVAAPP_BACKEND_DIR:-/opt/javaapp}"
service_name="${JAVAAPP_SERVICE_NAME:-javaapp}"

ensure_dir "$javaapp_dir"

log "Writing backend .env ..."
tmp_env="/tmp/javaapp.env.$$"
cat >"$tmp_env" <<EOF
SERVER_PORT=${SERVER_PORT:-8080}
POSTGRES_HOST=${POSTGRES_HOST:-127.0.0.1}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_DB=${DB_NAME:?}
POSTGRES_USER=${DB_USER:?}
POSTGRES_PASSWORD=${DB_PASSWORD:?}
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=${REDIS_PASSWORD:-}
FLUENTD_HOST=${FLUENTD_HOST:-127.0.0.1}
FLUENTD_PORT=${FLUENTD_PORT:-24224}
FLUENTD_ENABLED=${FLUENTD_ENABLED:-false}
DEBUG=${DEBUG_ENABLED:-false}
EOF
as_root mv "$tmp_env" "$javaapp_dir/.env"
as_root chown root:root "$javaapp_dir/.env"
as_root chmod 0640 "$javaapp_dir/.env"

log "Building backend JAR with Gradle in ${backend_project_dir} ..."
current_user="$(id -un)"
if [[ "$current_user" == "$user" ]]; then
  bash -lc "cd '${backend_project_dir}' && gradle bootJar"
else
sudo -u "$user" -H bash -lc "cd '${backend_project_dir}' && gradle bootJar"
fi

log "Deploying JAR to ${javaapp_dir}/app.jar ..."
as_root cp -f "${backend_project_dir}/build/libs/${backend_jar_name}" "${javaapp_dir}/app.jar"
as_root chown root:root "${javaapp_dir}/app.jar"
as_root chmod 0644 "${javaapp_dir}/app.jar"

unit_path="/etc/systemd/system/${service_name}.service"
log "Installing systemd unit ${unit_path} ..."
tmp_unit="/tmp/${service_name}.service.$$"
cat >"$tmp_unit" <<EOF
[Unit]
Description=JavaApp Backend
After=network.target

[Service]
EnvironmentFile=${javaapp_dir}/.env
WorkingDirectory=${javaapp_dir}
ExecStart=/usr/bin/java -jar ${javaapp_dir}/app.jar
User=www-data
Group=www-data
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
as_root mv "$tmp_unit" "$unit_path"
as_root systemctl daemon-reload
as_root systemctl enable --now "${service_name}"
log "Backend service ${service_name} started."

