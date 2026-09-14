#!/bin/sh
set -eu

# Use ViaTrack-specific variables so old template values in Railway cannot
# silently replace the resource profile baked into this service.
export GOMEMLIMIT="${GRAFANA_GOMEMLIMIT:-224MiB}"
export GOGC="${GRAFANA_GOGC:-40}"
export GOMAXPROCS="${GRAFANA_GOMAXPROCS:-1}"

# ViaTrack uses only Grafana's built-in panels and data sources. The original
# Railway template installed four legacy plugins during every container start.
unset GF_INSTALL_PLUGINS
unset GF_PLUGINS_PREINSTALL
unset GF_PLUGINS_PREINSTALL_SYNC

# A previous provider generated a second ViaTrack folder with a random UID.
# Once Grafana is ready, remove only empty duplicates and retain the folder
# managed by provisioning with the stable UID "viatrack".
cleanup_duplicate_folders() {
  if [ -z "${GF_SECURITY_ADMIN_USER:-}" ] || [ -z "${GF_SECURITY_ADMIN_PASSWORD:-}" ]; then
    return
  fi
  if ! command -v curl >/dev/null 2>&1; then
    return
  fi

  attempts=0
  until curl --fail --silent --output /dev/null \
    --user "${GF_SECURITY_ADMIN_USER}:${GF_SECURITY_ADMIN_PASSWORD}" \
    http://127.0.0.1:3000/api/health; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
      return
    fi
    sleep 2
  done

  folders="$(curl --fail --silent \
    --user "${GF_SECURITY_ADMIN_USER}:${GF_SECURITY_ADMIN_PASSWORD}" \
    'http://127.0.0.1:3000/api/search?type=dash-folder&query=ViaTrack' || true)"

  printf '%s\n' "$folders" | sed 's/},{/}\
{/g' | while IFS= read -r folder; do
    title="$(printf '%s' "$folder" | sed -n 's/.*"title":"\([^"]*\)".*/\1/p')"
    uid="$(printf '%s' "$folder" | sed -n 's/.*"uid":"\([^"]*\)".*/\1/p')"
    if [ "$title" != "ViaTrack" ] || [ -z "$uid" ] || [ "$uid" = "viatrack" ]; then
      continue
    fi

    contents="$(curl --fail --silent \
      --user "${GF_SECURITY_ADMIN_USER}:${GF_SECURITY_ADMIN_PASSWORD}" \
      "http://127.0.0.1:3000/api/search?folderUIDs=${uid}&type=dash-db" || true)"
    if [ "$contents" = "[]" ]; then
      curl --fail --silent --output /dev/null --request DELETE \
        --user "${GF_SECURITY_ADMIN_USER}:${GF_SECURITY_ADMIN_PASSWORD}" \
        "http://127.0.0.1:3000/api/folders/${uid}" || true
    fi
  done
}

cleanup_duplicate_folders &
exec /run.sh "$@"
