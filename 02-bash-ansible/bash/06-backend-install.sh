#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

apt_install git "${OPENJDK_PACKAGE:-openjdk-21-jdk}" unzip curl

gradle_version="${GRADLE_VERSION:-8.5}"
gradle_install_dir="${GRADLE_INSTALL_DIR:-/opt/gradle}"
ensure_dir "$gradle_install_dir"
tmp_zip="/tmp/gradle-${gradle_version}-bin.zip"
if [[ ! -d "$gradle_install_dir/gradle-${gradle_version}" ]]; then
  curl -fsSL "https://services.gradle.org/distributions/gradle-${gradle_version}-bin.zip" -o "$tmp_zip"
  as_root unzip -q "$tmp_zip" -d "$gradle_install_dir"
fi
as_root ln -sf "$gradle_install_dir/gradle-${gradle_version}/bin/gradle" /usr/local/bin/gradle

repo_url="${BACKEND_REPO_URL:?}"
repo_dest="${BACKEND_REPO_DEST:-/opt/java-app}"
repo_branch="${BACKEND_REPO_BRANCH:-main}"
user="${APP_USER:-julia}"
ensure_dir "$repo_dest" "$user" "$user" 0755

log "Cloning or updating backend repo at $repo_dest ..."
if [[ -n "${BACKEND_REPO_KEY_PATH:-}" && -f "${BACKEND_REPO_KEY_PATH:-}" ]]; then
  export GIT_SSH_COMMAND="ssh -i ${BACKEND_REPO_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
fi
if [[ ! -d "$repo_dest/.git" ]]; then
  if [[ -w "$(dirname "$repo_dest")" ]]; then
    git clone --branch "$repo_branch" "$repo_url" "$repo_dest"
  else
    if [[ -n "${GIT_SSH_COMMAND:-}" ]]; then
      as_root env GIT_SSH_COMMAND="${GIT_SSH_COMMAND}" git clone --branch "$repo_branch" "$repo_url" "$repo_dest"
    else
      as_root git clone --branch "$repo_branch" "$repo_url" "$repo_dest"
    fi
  fi
else
  if [[ -w "$repo_dest" ]]; then
    git -C "$repo_dest" fetch --all --prune
    git -C "$repo_dest" checkout "$repo_branch"
    git -C "$repo_dest" pull --ff-only
  else
    if [[ -n "${GIT_SSH_COMMAND:-}" ]]; then
      as_root env GIT_SSH_COMMAND="${GIT_SSH_COMMAND}" git -C "$repo_dest" fetch --all --prune
      as_root git -C "$repo_dest" checkout "$repo_branch"
      as_root env GIT_SSH_COMMAND="${GIT_SSH_COMMAND}" git -C "$repo_dest" pull --ff-only
    else
      as_root git -C "$repo_dest" fetch --all --prune
      as_root git -C "$repo_dest" checkout "$repo_branch"
      as_root git -C "$repo_dest" pull --ff-only
    fi
  fi
fi

# Ensure repository directory ownership belongs to application user
as_root chown -R "$user:$user" "$repo_dest"

log "Backend install complete."

