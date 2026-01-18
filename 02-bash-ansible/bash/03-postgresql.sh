#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

db_name="${DB_NAME:?}"
db_user="${DB_USER:?}"
db_password="${DB_PASSWORD:?}"

apt_install postgresql postgresql-contrib
as_root systemctl enable --now postgresql

log "Ensuring PostgreSQL role ${db_user} with LOGIN..."
sudo -u postgres psql -v ON_ERROR_STOP=1 -q <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${db_user}') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '${db_user}', '${db_password}');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '${db_user}', '${db_password}');
  END IF;
END
\$\$;
SQL

log "Ensuring database ${db_name} owned by ${db_user}..."
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" | grep -q 1; then
  log "Creating database ${db_name} owned by ${db_user} ..."
  sudo -u postgres createdb -O "${db_user}" "${db_name}"
else
  log "Database ${db_name} exists, ensuring owner is ${db_user} ..."
  sudo -u postgres psql -v ON_ERROR_STOP=1 -q -c "ALTER DATABASE \"${db_name}\" OWNER TO \"${db_user}\""
fi

log "Granting ALL on schema public to ${db_user}..."
sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d "$db_name" \
  -c "GRANT ALL ON SCHEMA public TO ${db_user};"

log "PostgreSQL setup complete."

