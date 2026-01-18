#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

if [[ -f "$project_root/config.env" ]]; then
  # shellcheck disable=SC1091
  source "$project_root/config.env"
fi

log() { printf '[%s] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$*" >&2; }

as_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

expand_path() {
  # Expand ~ and env vars inside a path string
  local p="$1"
  eval "printf '%s' \"$p\""
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "This script must be run as root (sudo)."
    exit 1
  fi
}

apt_install() {
  as_root env DEBIAN_FRONTEND=noninteractive apt-get update -y
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

ensure_dir() {
  local path="$1" owner="${2:-root}" group="${3:-root}" mode="${4:-0755}"
  as_root install -d -m "$mode" -o "$owner" -g "$group" "$path"
}

render_file() {
  # Simple envsubst-like renderer using bash parameter expansion.
  # Usage: render_file SRC DEST
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  # shellcheck disable=SC2016
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    awk 'BEGIN{ while((getline line<ARGV[1])>0){ print line } }' "$src" | \
    sudo bash -c 'cat > "$1"' _ "$dest"
  else
    awk 'BEGIN{ while((getline line<ARGV[1])>0){ print line } }' "$src" | \
    bash -c 'cat > "$1"' _ "$dest"
  fi
}

user_home() {
  local user="$1"
  getent passwd "$user" | cut -d: -f6
}